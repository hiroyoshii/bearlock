#!/usr/bin/env python3
"""Regression: target stays open across service reconnection, then expires normally.
Runs only on an emulator; restores the original accessibility service settings.
"""
import argparse
import json
from pathlib import Path
import re
import subprocess
import time
import xml.etree.ElementTree as ET

LAB = "com.hiyozoo.bearlock.lab"
PROBE = "com.hiyozoo.bearlock.probe"
SERVICE = f"{LAB}/{LAB}.AccessMonitor"


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--adb", default="adb")
    p.add_argument("--serial", required=True)
    p.add_argument("--output", required=True, type=Path)
    args = p.parse_args()
    if not args.serial.startswith("emulator-"):
        p.error("Use an emulator.")
    args.output.mkdir(parents=True, exist_ok=True)

    def adb(*cmd, binary=False):
        r = subprocess.run([args.adb, "-s", args.serial, *map(str, cmd)], capture_output=True, timeout=30, check=True)
        return r.stdout if binary else r.stdout.decode(errors="replace").strip()

    def shell(*cmd): return adb("shell", *cmd)
    def now(): return int(shell("date", "+%s%3N"))
    def events():
        return [json.loads(s) for s in adb("exec-out", "run-as", LAB, "cat", "files/events.jsonl").splitlines()]
    def screenshot(name):
        (args.output / f"{name}.png").write_bytes(adb("exec-out", "screencap", "-p", binary=True))
    def wait_event(start, predicate):
        deadline = time.monotonic() + 20
        while time.monotonic() < deadline:
            found = next((e for e in events()[start:] if predicate(e)), None)
            if found: return found
            time.sleep(.3)
        raise AssertionError("Required event did not arrive")

    original = shell("settings", "get", "secure", "enabled_accessibility_services")
    original_enabled = shell("settings", "get", "secure", "accessibility_enabled")
    others = [s for s in original.split(":") if s not in ["", "null", SERVICE]]
    def enable(enabled):
        names = others + ([SERVICE] if enabled else [])
        shell("settings", "put", "secure", "enabled_accessibility_services", ":".join(names) or "null")
        shell("settings", "put", "secure", "accessibility_enabled", 1 if names else 0)

    result = {}
    try:
        enable(False)
        shell("input", "keyevent", "KEYCODE_WAKEUP")
        shell("input", "keyevent", "82")
        shell("am", "start", "-W", "-n", f"{PROBE}/.ProbeActivity")
        shell("uiautomator", "dump", "/sdcard/bearlock-lab-window.xml")
        tree = ET.fromstring(shell("cat", "/sdcard/bearlock-lab-window.xml"))
        node = next(n for n in tree.iter("node") if n.attrib.get("text", "").startswith("タップ試験"))
        x1, y1, x2, y2 = map(int, re.findall(r"\d+", node.attrib["bounds"]))
        point = ((x1 + x2) // 2, (y1 + y2) // 2)
        before = len(events())
        enable(True)
        wait_event(before, lambda e: e["event"] == "access_service_connected")
        shell("am", "start", "-W", "-n", f"{LAB}/.ExperimentActivity", "--es", "method", "ACCESSIBILITY", "--ei", "duration", 60)
        window = wait_event(before, lambda e: e["event"] == "created")
        result["window"] = window
        enable(False)
        time.sleep(1)
        shell("am", "start", "-W", "-n", f"{PROBE}/.ProbeActivity")
        shell("input", "tap", *point)  # Positive control while the service is disabled.
        reconnect_start = len(events())
        result["targetOpenedBeforeReconnectMs"] = now()
        enable(True)  # Do not relaunch or interact with the target until the snapshot recovers it.
        connected = wait_event(reconnect_start, lambda e: e["event"] == "access_service_connected")
        snapshot = wait_event(reconnect_start, lambda e: e["event"] == "foreground_snapshot" and e["isTarget"])
        wait_event(reconnect_start, lambda e: e["event"] == "overlay_added")
        result["connected"] = connected
        result["snapshot"] = snapshot
        assert result["targetOpenedBeforeReconnectMs"] < connected["wallMs"]
        assert now() < window["end"] - 2000
        screenshot("reconnected-active")
        result["blockedTapMs"] = now()
        shell("input", "tap", *point)
        time.sleep(.5)
        home_start = len(events())
        shell("input", "keyevent", "KEYCODE_HOME")
        wait_event(home_start, lambda e: e["event"] == "overlay_removed")
        screenshot("home-after-recovery")
        shell("am", "start", "-W", "-n", f"{PROBE}/.ProbeActivity")
        wait_event(home_start, lambda e: e["event"] == "overlay_added")
        while now() < window["end"] + 1000: time.sleep(2)
        result["postEndTapMs"] = now()
        shell("input", "tap", *point)
        screenshot("expired")
        enable(False)
        time.sleep(1)
        expired_start = len(events())
        enable(True)
        wait_event(expired_start, lambda e: e["event"] == "access_service_connected")
        time.sleep(2)
        assert not any(e["event"] == "overlay_added" for e in events()[expired_start:])
        result["postExpiryReconnectTapMs"] = now()
        shell("input", "tap", *point)
        time.sleep(.5)
        raw = adb("logcat", "-d", "-v", "raw", "-s", "BearLockProbe:I", "*:S")
        probe_events = []
        for line in raw.splitlines():
            m = re.search(r"(resume|pause|tap) wallMs=(\d+) uptimeMs=(\d+) taps=(\d+)", line)
            if m and int(m[2]) >= window["wallMs"]:
                probe_events.append(dict(event=m[1], wallMs=int(m[2]), taps=int(m[4])))
        result["probeEvents"] = probe_events
        assert any(e["event"] == "tap" and e["wallMs"] < connected["wallMs"] for e in probe_events)
        assert not any(e["event"] == "tap" and connected["wallMs"] <= e["wallMs"] < window["end"] for e in probe_events)
        assert sum(e["event"] == "tap" and e["wallMs"] >= window["end"] for e in probe_events) == 2
        result["passed"] = True
        print("PASS: already-open target recovered; active tap blocked; Home/re-entry and expiration/reconnect passed.", flush=True)
    except Exception as error:
        result["passed"] = False
        result["error"] = repr(error)
        raise
    finally:
        result["events"] = events()[before:] if "before" in locals() else []
        (args.output / "reconnect-results.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
        shell("settings", "put", "secure", "enabled_accessibility_services", original)
        if original_enabled == "null": shell("settings", "delete", "secure", "accessibility_enabled")
        else: shell("settings", "put", "secure", "accessibility_enabled", original_enabled)


if __name__ == "__main__": main()
