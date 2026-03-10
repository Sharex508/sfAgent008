from __future__ import annotations

import json
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional

import imageio.v2 as iio
import numpy as np
from PIL import Image

from llm.ollama_client import OllamaClient


@dataclass
class FrameSample:
    index: int
    timestamp_s: float
    frame_path: str


def _sec_to_ts(sec: float) -> str:
    total = int(max(0, round(sec)))
    h = total // 3600
    m = (total % 3600) // 60
    s = total % 60
    return f"{h:02d}:{m:02d}:{s:02d}"


def _extract_samples(
    video_path: str,
    output_dir: Path,
    interval_seconds: int = 5,
    max_frames: int = 80,
) -> List[FrameSample]:
    reader = iio.get_reader(video_path)
    meta = reader.get_meta_data() or {}
    fps = float(meta.get("fps") or 30.0)
    step = max(1, int(interval_seconds * fps))

    samples: List[FrameSample] = []
    idx = 0
    for i, frame in enumerate(reader):
        if i % step != 0:
            continue
        ts = i / fps
        out = output_dir / f"frame_{idx:04d}.jpg"
        img = Image.fromarray(frame)
        img.save(out, format="JPEG", quality=85)
        samples.append(FrameSample(index=idx, timestamp_s=ts, frame_path=str(out)))
        idx += 1
        if idx >= max_frames:
            break

    reader.close()
    return samples


def _scene_boundaries(samples: List[FrameSample], diff_threshold: float = 22.0) -> List[FrameSample]:
    if not samples:
        return []
    selected: List[FrameSample] = [samples[0]]

    prev = np.array(Image.open(samples[0].frame_path).convert("RGB"), dtype=np.float32)
    for sm in samples[1:]:
        cur = np.array(Image.open(sm.frame_path).convert("RGB"), dtype=np.float32)
        # Mean absolute pixel difference in [0,255]
        mad = float(np.mean(np.abs(cur - prev)))
        if mad >= diff_threshold:
            selected.append(sm)
            prev = cur

    # Always include last frame for closure
    if selected[-1].frame_path != samples[-1].frame_path:
        selected.append(samples[-1])

    return selected


def _pick_vision_model(ollama: OllamaClient, preferred: Optional[str]) -> Optional[str]:
    models = ollama.list_models()
    if preferred and preferred in models:
        return preferred

    keywords = ("llava", "vision", "vl", "moondream", "bakllava")
    for name in models:
        low = name.lower()
        if any(k in low for k in keywords):
            return name
    return None


def _can_model_see_images(ollama_host: str, model: str, probe_image_path: str) -> bool:
    client = OllamaClient(host=ollama_host, model=model)
    try:
        out = client.chat_with_images("Describe this image briefly.", [probe_image_path])
        return bool(out and out.strip())
    except Exception:
        return False


def _describe_frames_with_vision(
    *,
    ollama_host: str,
    model: str,
    keyframes: List[FrameSample],
) -> List[Dict[str, Any]]:
    vis = OllamaClient(host=ollama_host, model=model)
    out: List[Dict[str, Any]] = []

    for sm in keyframes:
        prompt = (
            "You are analyzing a Salesforce UI test recording frame. "
            "Describe visible UI action/state in one short sentence. "
            "Focus on object, page, button/action, and form state if visible."
        )
        try:
            desc = vis.chat_with_images(prompt, [sm.frame_path]).strip()
        except Exception as exc:
            desc = f"Vision analysis failed: {exc}"
        out.append(
            {
                "timestamp_s": round(sm.timestamp_s, 2),
                "timestamp": _sec_to_ts(sm.timestamp_s),
                "frame_path": sm.frame_path,
                "description": desc,
            }
        )
    return out


def _synthesize_steps(
    *,
    ollama_host: str,
    llm_model: str,
    frame_notes: List[Dict[str, Any]],
    video_name: str,
    semantic_enabled: bool,
) -> List[Dict[str, Any]]:
    # If no semantic descriptions are available, emit deterministic timeline steps only.
    if not frame_notes:
        return []
    if not semantic_enabled:
        steps = []
        for i, n in enumerate(frame_notes, start=1):
            instruction = str(n.get("description") or "UI state change detected; semantic label unavailable.").strip()
            steps.append(
                {
                    "step_number": i,
                    "timestamp": n["timestamp"],
                    "timestamp_s": n["timestamp_s"],
                    "title": "Screen/State change",
                    "instruction": instruction,
                    "evidence_frame": n["frame_path"],
                }
            )
        return steps

    prompt = (
        "Convert timeline notes into step-by-step Salesforce execution instructions.\n"
        "Rules:\n"
        "- Output strict JSON only: {\"steps\":[...]}\n"
        "- Each item must include: step_number, timestamp, timestamp_s, title, instruction, evidence_frame\n"
        "- step_number must be sequential from 1 upward\n"
        "- Do not invent UI artifacts not in the notes\n"
        "- title should be short (<=10 words)\n"
        "- instruction should be one concrete action sentence\n"
        "- Return only one JSON object and no extra text\n"
        "- If uncertain use placeholder: \\\"UI element unclear; infer from adjacent frames\\\"\n\n"
        f"VIDEO: {video_name}\n"
        f"FRAME_NOTES:\n{json.dumps(frame_notes, ensure_ascii=False)}"
    )
    text_llm = OllamaClient(host=ollama_host, model=llm_model)
    try:
        raw = text_llm.chat(prompt)
        start = raw.find("{")
        end = raw.rfind("}")
        if start >= 0 and end > start:
            parsed = json.loads(raw[start : end + 1])
            steps = parsed.get("steps")
            if isinstance(steps, list):
                normalized: List[Dict[str, Any]] = []
                for i, raw_step in enumerate(steps, start=1):
                    if not isinstance(raw_step, dict):
                        continue
                    title = str(raw_step.get("title") or f"Step {i}").strip()
                    instruction = str(raw_step.get("instruction") or "").strip()
                    if not instruction:
                        instruction = "UI action inferred from frame sequence."
                    evidence_frame = str(raw_step.get("evidence_frame") or "").strip()
                    normalized.append(
                        {
                            "step_number": i,
                            "timestamp": str(raw_step.get("timestamp") or "00:00:00"),
                            "timestamp_s": float(raw_step.get("timestamp_s") or 0.0),
                            "title": title,
                            "instruction": instruction,
                            "evidence_frame": evidence_frame,
                        }
                    )
                if normalized:
                    return normalized
    except Exception:
        pass

    # Fallback if JSON synthesis fails.
    steps = []
    for i, n in enumerate(frame_notes, start=1):
        desc = str(n.get("description") or "UI transition").strip()
        steps.append(
            {
                "step_number": i,
                "timestamp": n["timestamp"],
                "timestamp_s": n["timestamp_s"],
                "title": f"Step {i}",
                "instruction": desc,
                "evidence_frame": n["frame_path"],
            }
        )
    return steps


def analyze_video_to_steps(
    *,
    capture_id: str,
    video_path: str,
    artifacts_dir: Path,
    ollama_host: str = "http://localhost:11434",
    llm_model: str = "gpt-oss:20b",
    vision_model: Optional[str] = None,
    interval_seconds: int = 5,
    max_frames: int = 80,
) -> Dict[str, Any]:
    artifacts_dir.mkdir(parents=True, exist_ok=True)
    frames_dir = artifacts_dir / "frames"
    frames_dir.mkdir(parents=True, exist_ok=True)

    samples = _extract_samples(
        video_path=video_path,
        output_dir=frames_dir,
        interval_seconds=interval_seconds,
        max_frames=max_frames,
    )
    keyframes = _scene_boundaries(samples)

    probe_ollama = OllamaClient(host=ollama_host, model=llm_model)
    picked_vision = _pick_vision_model(probe_ollama, vision_model)
    if not picked_vision and keyframes:
        # Fallback: some text models (e.g., gpt-oss variants) can still accept image inputs.
        if _can_model_see_images(ollama_host, llm_model, keyframes[0].frame_path):
            picked_vision = llm_model

    if picked_vision:
        notes = _describe_frames_with_vision(
            ollama_host=ollama_host,
            model=picked_vision,
            keyframes=keyframes,
        )
        vision_used = True
    else:
        notes = [
            {
                "timestamp_s": round(sm.timestamp_s, 2),
                "timestamp": _sec_to_ts(sm.timestamp_s),
                "frame_path": sm.frame_path,
                "description": "Vision model unavailable on Ollama; semantic frame description skipped.",
            }
            for sm in keyframes
        ]
        vision_used = False

    steps = _synthesize_steps(
        ollama_host=ollama_host,
        llm_model=llm_model,
        frame_notes=notes,
        video_name=Path(video_path).name,
        semantic_enabled=vision_used,
    )

    return {
        "capture_id": capture_id,
        "video_path": video_path,
        "generated_at": datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
        "status": "OK",
        "vision_used": vision_used,
        "vision_model": picked_vision,
        "llm_model": llm_model,
        "frame_sample_count": len(samples),
        "keyframe_count": len(keyframes),
        "frame_notes": notes,
        "steps": steps,
    }
