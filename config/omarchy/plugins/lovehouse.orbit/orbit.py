#!/usr/bin/python3
"""Orbit Desk state engine. No network or third-party dependencies."""
import argparse
import datetime as dt
import fcntl
import json
import math
import os
from pathlib import Path
import subprocess
import tempfile
import time


def initial():
    return dict(version=1, phase="idle", kind="focus", duration=1500,
                remaining=1500, deadline=0, note="", history=[])


def transition(state, action, value=None, now=None):
    now = time.time() if now is None else now
    completed = False
    if state["phase"] == "running" and now >= state["deadline"]:
        if state["kind"] == "focus":
            state["history"].append({"ended": state["deadline"], "seconds": state["duration"]})
            state["history"] = state["history"][-1000:]
        state.update(phase="done", remaining=0, deadline=0)
        completed = True
    if action == "start":
        if value not in (5, 25, 50):
            raise ValueError("지원 시간: 5, 25, 50분")
        if state["phase"] in ("running", "paused"):
            raise ValueError("진행 중인 타이머를 먼저 종료해 주세요.")
        seconds = value * 60
        state.update(phase="running", kind="break" if value == 5 else "focus",
                     duration=seconds, remaining=seconds, deadline=now + seconds)
    elif action == "pause" and state["phase"] == "running":
        state.update(remaining=max(0, state["deadline"] - now), deadline=0, phase="paused")
    elif action == "resume" and state["phase"] == "paused":
        state.update(deadline=now + state["remaining"], phase="running")
    elif action == "reset":
        state.update(phase="idle", remaining=state["duration"], deadline=0)
    elif action == "note":
        state["note"] = str(value)[:240]
    return completed


def snapshot(state, now=None):
    now = time.time() if now is None else now
    out = dict(state)
    out.pop("history")
    today = dt.datetime.fromtimestamp(now).date()
    sessions = [x for x in state["history"] if dt.datetime.fromtimestamp(x["ended"]).date() == today]
    out["today_sessions"] = len(sessions)
    out["today_minutes"] = sum(x["seconds"] for x in sessions) // 60
    out["remaining"] = math.ceil(max(0, state["deadline"] - now)) if state["phase"] == "running" else math.ceil(state["remaining"])
    return out


def execute(directory, action="status", value=None, now=None, notify=True):
    directory.mkdir(parents=True, exist_ok=True, mode=0o700)
    path = directory / "state.json"
    with (directory / "state.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        state = json.loads(path.read_text()) if path.exists() else initial()
        before = json.dumps(state, ensure_ascii=False)
        completed = transition(state, action, value, now)
        if not path.exists() or before != json.dumps(state, ensure_ascii=False):
            fd, temp = tempfile.mkstemp(dir=directory, prefix=".state-")
            try:
                with os.fdopen(fd, "w") as stream:
                    json.dump(state, stream, ensure_ascii=False)
                    stream.flush()
                    os.fsync(stream.fileno())
                os.replace(temp, path)
            finally:
                if os.path.exists(temp):
                    os.unlink(temp)
        result = snapshot(state, now)
    # Completion is claimed under the lock, so multiple monitors notify once.
    if completed and notify:
        message = "집중 세션 완료! 잠시 쉬어 가세요." if result["kind"] == "focus" else "휴식 완료! 다음 작업을 시작해 볼까요?"
        try:
            subprocess.run(["notify-send", "--app-name=Orbit Desk", "Orbit Desk", message],
                           timeout=3, check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except (OSError, subprocess.TimeoutExpired):
            pass
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["status", "start", "pause", "resume", "reset", "note"], nargs="?", default="status")
    parser.add_argument("value", nargs="?")
    args = parser.parse_args()
    directory = Path(os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local/state"))) / "orbit-desk"
    try:
        value = int(args.value) if args.action == "start" else args.value
        if args.action == "note" and value is None:
            raise ValueError("메모 내용을 입력해 주세요.")
        print(json.dumps(execute(directory, args.action, value), ensure_ascii=False))
    except (OSError, ValueError, KeyError, TypeError) as error:
        print(json.dumps({"error": str(error)}, ensure_ascii=False))
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
