from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional


def _utc_now_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def _load_playwright():
    try:
        from playwright.sync_api import TimeoutError as PlaywrightTimeoutError
        from playwright.sync_api import sync_playwright
    except ImportError as exc:
        raise RuntimeError(
            "Playwright is not installed. Install the Python package and browser runtime with "
            "`pip install playwright` and `playwright install chromium` before running UI features."
        ) from exc
    return sync_playwright, PlaywrightTimeoutError


def _as_text(value: Any) -> str:
    if value is None:
        return ""
    if isinstance(value, str):
        return value
    return json.dumps(value, ensure_ascii=False)


def _screenshot_path(root: Path, step_index: int, step_name: str) -> Path:
    safe_name = "".join(ch if ch.isalnum() else "-" for ch in (step_name or f"step-{step_index + 1}")).strip("-")
    if not safe_name:
        safe_name = f"step-{step_index + 1}"
    return root / f"{step_index + 1:02d}-{safe_name}.png"


def _write_json(path: Path, payload: Dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, ensure_ascii=False), encoding="utf-8")


def _execute_step(page: Any, step: Dict[str, Any], *, base_url: Optional[str], default_timeout_ms: int) -> Dict[str, Any]:
    action = str(step.get("action") or "").strip().lower()
    step_timeout = int(step.get("timeout_ms") or default_timeout_ms)
    selector = step.get("selector")
    value = step.get("value")
    expected_text = step.get("text")
    url = step.get("url")

    if not action:
        raise ValueError("Each step requires a non-empty action.")

    if action == "goto":
        destination = str(url or "").strip()
        if not destination:
            raise ValueError("goto step requires a url.")
        if base_url and destination.startswith("/"):
            destination = f"{base_url.rstrip('/')}{destination}"
        page.goto(destination, wait_until="domcontentloaded", timeout=step_timeout)
        return {"url": page.url}

    if action == "wait_for":
        if selector:
            page.locator(selector).first.wait_for(timeout=step_timeout)
            return {"selector": selector}
        page.wait_for_timeout(step_timeout)
        return {"waited_ms": step_timeout}

    if action == "screenshot":
        return {"url": page.url}

    if not selector:
        raise ValueError(f"{action} step requires a selector.")

    locator = page.locator(selector).first
    if action == "click":
        locator.click(timeout=step_timeout)
        return {"selector": selector}
    if action == "fill":
        locator.fill("" if value is None else str(value), timeout=step_timeout)
        return {"selector": selector, "value": _as_text(value)}
    if action == "press":
        locator.press("" if value is None else str(value), timeout=step_timeout)
        return {"selector": selector, "value": _as_text(value)}
    if action == "select":
        locator.select_option("" if value is None else str(value), timeout=step_timeout)
        return {"selector": selector, "value": _as_text(value)}
    if action == "expect_visible":
        locator.wait_for(state="visible", timeout=step_timeout)
        return {"selector": selector}
    if action == "expect_text":
        locator.wait_for(state="visible", timeout=step_timeout)
        actual_text = locator.inner_text(timeout=step_timeout)
        if str(expected_text or "") not in actual_text:
            raise AssertionError(f"Expected text '{expected_text}' not found. Actual text: {actual_text[:500]}")
        return {"selector": selector, "actual_text": actual_text}

    raise ValueError(f"Unsupported UI step action: {action}")


def run_ui_feature_session(
    *,
    feature: Dict[str, Any],
    run_id: str,
    artifact_root: Path,
    target_org_alias: Optional[str] = None,
    base_url: Optional[str] = None,
    start_url: Optional[str] = None,
    browser_name: str = "chromium",
    headless: bool = True,
    slow_mo_ms: int = 0,
    timeout_ms: int = 15000,
    storage_state_path: Optional[str] = None,
    record_video: bool = True,
    record_trace: bool = True,
    locale: str = "en-US",
    timezone_id: str = "UTC",
) -> Dict[str, Any]:
    sync_playwright, PlaywrightTimeoutError = _load_playwright()

    steps = list(feature.get("steps") or [])
    if not steps:
        raise ValueError("The UI feature has no saved steps to run.")

    artifact_root = artifact_root.resolve()
    screenshot_root = artifact_root / "screenshots"
    video_root = artifact_root / "video"
    trace_root = artifact_root / "trace"
    screenshot_root.mkdir(parents=True, exist_ok=True)
    if record_video:
        video_root.mkdir(parents=True, exist_ok=True)
    if record_trace:
        trace_root.mkdir(parents=True, exist_ok=True)

    step_results: List[Dict[str, Any]] = []
    summary: Dict[str, Any] = {
        "run_id": run_id,
        "feature_id": feature.get("feature_id"),
        "feature_name": feature.get("name"),
        "target_org_alias": target_org_alias or feature.get("target_org_alias"),
        "started_ts": _utc_now_iso(),
        "status": "RUNNING",
    }
    trace_path: Optional[str] = None
    video_path: Optional[str] = None
    current_url: Optional[str] = None

    with sync_playwright() as playwright:
        browser_launcher = getattr(playwright, browser_name, None)
        if browser_launcher is None:
            raise ValueError(f"Unsupported browser: {browser_name}")

        browser = browser_launcher.launch(headless=headless, slow_mo=slow_mo_ms or None)
        context_kwargs: Dict[str, Any] = {
            "ignore_https_errors": True,
            "locale": locale,
            "timezone_id": timezone_id,
        }
        if record_video:
            context_kwargs["record_video_dir"] = str(video_root)
        if storage_state_path:
            context_kwargs["storage_state"] = storage_state_path

        context = browser.new_context(**context_kwargs)
        page = context.new_page()

        try:
            if record_trace:
                context.tracing.start(screenshots=True, snapshots=True, sources=True)

            entry_url = start_url or feature.get("start_url")
            if entry_url:
                if base_url and str(entry_url).startswith("/"):
                    entry_url = f"{base_url.rstrip('/')}{entry_url}"
                page.goto(str(entry_url), wait_until="domcontentloaded", timeout=timeout_ms)
                current_url = page.url

            for idx, step in enumerate(steps):
                step_name = str(step.get("name") or f"Step {idx + 1}")
                action = str(step.get("action") or "").strip().lower()
                started_ts = _utc_now_iso()
                result: Dict[str, Any] = {
                    "step_index": idx,
                    "step_name": step_name,
                    "action_type": action,
                    "selector": step.get("selector"),
                    "expected_text": step.get("text"),
                    "status": "RUNNING",
                    "started_ts": started_ts,
                    "finished_ts": None,
                    "screenshot_path": None,
                    "error_text": None,
                    "result": None,
                }
                screenshot_path = _screenshot_path(screenshot_root, idx, step_name)
                try:
                    payload = _execute_step(page, step, base_url=base_url, default_timeout_ms=timeout_ms)
                    if bool(step.get("screenshot_after")) or action in {"screenshot", "expect_text"}:
                        page.screenshot(path=str(screenshot_path), full_page=True)
                        result["screenshot_path"] = str(screenshot_path)
                    result["status"] = "PASSED"
                    result["result"] = payload
                except (AssertionError, PlaywrightTimeoutError, Exception) as exc:
                    try:
                        page.screenshot(path=str(screenshot_path), full_page=True)
                        result["screenshot_path"] = str(screenshot_path)
                    except Exception:
                        pass
                    result["status"] = "FAILED"
                    result["error_text"] = str(exc)
                    result["finished_ts"] = _utc_now_iso()
                    step_results.append(result)
                    raise
                result["finished_ts"] = _utc_now_iso()
                current_url = page.url
                step_results.append(result)

            summary["status"] = "PASSED"
        except Exception as exc:
            summary["status"] = "FAILED"
            summary["error"] = str(exc)
        finally:
            summary["finished_ts"] = _utc_now_iso()
            summary["current_url"] = current_url or page.url
            summary["step_results"] = step_results
            if record_trace:
                trace_file = trace_root / f"{run_id}.zip"
                context.tracing.stop(path=str(trace_file))
                trace_path = str(trace_file)
            context.close()
            browser.close()

    if record_video:
        videos = sorted(video_root.glob("**/*.webm"))
        if videos:
            video_path = str(videos[-1])

    summary["artifacts"] = {
        "artifact_root": str(artifact_root),
        "trace_path": trace_path,
        "video_path": video_path,
        "screenshot_root": str(screenshot_root),
    }
    _write_json(artifact_root / "summary.json", summary)
    return summary
