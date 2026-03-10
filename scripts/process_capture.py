#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

# Ensure project root is importable when invoked as ./scripts/process_capture.py
ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from process.capture import ingest_video, save_process, start_capture, stop_capture
from process.storage import CaptureStore
from sfdc.tooling_client import SalesforceToolingClient


def _mk_client(args):
    return SalesforceToolingClient.from_soap_login(
        login_url=args.login_url,
        username=args.username,
        password=args.password,
        token=args.token,
        api_version=args.api_version,
    )


def cmd_start(args):
    client = _mk_client(args)
    res = start_capture(
        client=client,
        user=args.user,
        minutes=args.minutes,
        filter_text=args.filter_text,
        tail_seconds=args.tail_seconds,
        store=CaptureStore(),
    )
    print(json.dumps(res.__dict__, indent=2))


def cmd_stop(args):
    client = _mk_client(args)
    res = stop_capture(
        client=client,
        capture_id=args.capture_id,
        analyze=args.analyze,
        llm=args.llm,
        llm_model=args.llm_model,
        ollama_host=args.ollama_host,
        store=CaptureStore(),
    )
    print(json.dumps(res.__dict__, indent=2))


def cmd_save(args):
    res = save_process(
        capture_id=args.capture_id,
        name=args.name,
        description=args.description,
        store=CaptureStore(),
    )
    print(json.dumps(res, indent=2))


def cmd_video_ingest(args):
    res = ingest_video(
        capture_id=args.capture_id,
        video_path=args.video,
        analyze=args.analyze,
        llm_model=args.llm_model,
        vision_model=args.vision_model,
        ollama_host=args.ollama_host,
        interval_seconds=args.interval_seconds,
        max_frames=args.max_frames,
        store=CaptureStore(),
    )
    print(json.dumps(res, indent=2))


def add_sf_auth(parser):
    parser.add_argument("--login-url", default=None)
    parser.add_argument("--username", default=None)
    parser.add_argument("--password", default=None)
    parser.add_argument("--token", default=None)
    parser.add_argument("--api-version", default=None)


def main():
    p = argparse.ArgumentParser(description="Process capture utility")
    sub = p.add_subparsers(dest="cmd", required=True)

    p_start = sub.add_parser("start", help="Start process capture")
    add_sf_auth(p_start)
    p_start.add_argument("--user", required=True)
    p_start.add_argument("--minutes", type=int, default=10)
    p_start.add_argument("--tail-seconds", type=int, default=120)
    p_start.add_argument("--filter-text", default=None)
    p_start.set_defaults(func=cmd_start)

    p_stop = sub.add_parser("stop", help="Stop process capture")
    add_sf_auth(p_stop)
    p_stop.add_argument("--capture-id", required=True)
    p_stop.add_argument("--analyze", action="store_true")
    p_stop.add_argument("--llm", action="store_true")
    p_stop.add_argument("--llm-model", default="gpt-oss:20b")
    p_stop.add_argument("--ollama-host", default=None)
    p_stop.set_defaults(func=cmd_stop)

    p_save = sub.add_parser("save", help="Save process definition")
    p_save.add_argument("--capture-id", required=True)
    p_save.add_argument("--name", required=True)
    p_save.add_argument("--description", default=None)
    p_save.set_defaults(func=cmd_save)

    p_video = sub.add_parser("video-ingest", help="Attach video and generate step instructions")
    p_video.add_argument("--capture-id", required=True)
    p_video.add_argument("--video", required=True)
    p_video.add_argument("--analyze", action="store_true")
    p_video.add_argument("--llm-model", default="gpt-oss:20b")
    p_video.add_argument("--vision-model", default=None)
    p_video.add_argument("--ollama-host", default=None)
    p_video.add_argument("--interval-seconds", type=int, default=5)
    p_video.add_argument("--max-frames", type=int, default=80)
    p_video.set_defaults(func=cmd_video_ingest)

    args = p.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
