#!/usr/bin/env python3
"""Verify persisted lock + enforcement after an emulator reboot; run after compare.py.

Uses the debug-only probe harness. Temporarily changes only lab appops and the
accessibility service list, restoring the latter. Each experiment defaults to 180 seconds.
"""
import argparse
import json
from pathlib import Path
import subprocess
import time
import re
import xml.etree.ElementTree as ET

LAB = "com.hiyozoo.bearlock.lab"
PROBE = "com.hiyozoo.bearlock.probe"
SERVICE = f"{LAB}/{LAB}.AccessMonitor"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--adb", default="adb")
    parser.add_argument("--serial", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--method", choices=["USAGE", "ACCESSIBILITY", "BOTH"], default="BOTH")
    parser.add_argument("--duration", type=int, default=180)
    args = parser.parse_args()
    if not args.serial.startswith("emulator-"):
        parser.error("Use an emulator.")
    if not 90 <= args.duration <= 300:
        parser.error("Reboot experiments require 90–300 seconds.")
    args.output.mkdir(parents=True, exist_ok=True)

    def adb(*cmd, binary=False):
        r = subprocess.run([args.adb, "-s", args.serial, *cmd], check=True, capture_output=True, timeout=35)
        return r.stdout if binary else r.stdout.decode(errors="replace").strip()

    def shell(*cmd):
        return adb("shell", *map(str, cmd))

    def events():
        return [json.loads(s) for s in adb("exec-out", "run-as", LAB, "cat", "files/events.jsonl").splitlines()]

    original = shell("settings", "get", "secure", "enabled_accessibility_services")
    original_enabled = shell("settings", "get", "secure", "accessibility_enabled")
    results = []
    try:
        shell("input", "keyevent", "KEYCODE_WAKEUP")
        shell("input", "keyevent", "82")
        shell("am", "start", "-W", "-n", f"{PROBE}/.ProbeActivity")
        shell("uiautomator", "dump", "/sdcard/bearlock-lab-window.xml")
        tree = ET.fromstring(shell("cat", "/sdcard/bearlock-lab-window.xml"))
        target_button = next(n for n in tree.iter("node") if n.attrib.get("text", "").startswith("タップ試験"))
        x1, y1, x2, y2 = map(int, re.findall(r"\d+", target_button.attrib["bounds"]))
        tap_point = ((x1 + x2) // 2, (y1 + y2) // 2)
        for method in (["USAGE", "ACCESSIBILITY"] if args.method == "BOTH" else [args.method]):
            connect_before = len(events())
            services = [s for s in original.split(":") if s not in ["", "null", SERVICE]]
            if method == "ACCESSIBILITY":
                services.append(SERVICE)
            shell("settings", "put", "secure", "enabled_accessibility_services", ":".join(services) or "null")
            shell("settings", "put", "secure", "accessibility_enabled", "1" if services else "0")
            time.sleep(2)
            if method == "ACCESSIBILITY" and SERVICE not in original:
                deadline = time.monotonic() + 20
                while time.monotonic() < deadline:
                    if any(e["event"] == "access_service_connected" for e in events()[connect_before:]):
                        break
                    time.sleep(1)
                else:
                    raise RuntimeError("Accessibility service did not connect")
            before = len(events())
            shell("am", "start", "-W", "-n", f"{LAB}/.ExperimentActivity", "--es", "method", method, "--ei", "duration", args.duration)
            created = next((e for e in events()[before:] if e["event"] == "created"), None)
            if created is None:
                raise RuntimeError(f"Experiment was rejected: {events()[before:]}")
            adb("reboot")
            # Allow the emulator to leave its old ready state, then wait with bounded ADB calls.
            time.sleep(5)
            deadline = time.monotonic() + args.duration - 20
            while time.monotonic() < deadline:
                try:
                    if shell("getprop", "sys.boot_completed") == "1":
                        break
                except (subprocess.SubprocessError, OSError):
                    pass
                time.sleep(2)
            else:
                raise RuntimeError("Emulator did not boot within the experiment budget")
            shell("input", "keyevent", "KEYCODE_WAKEUP")
            shell("input", "keyevent", "82")
            launch_started_at = int(shell("date", "+%s%3N"))
            shell("am", "start", "-W", "-n", f"{PROBE}/.ProbeActivity")
            launched_at = int(shell("date", "+%s%3N"))
            # Do not relaunch the target while waiting: recovery must handle an already-open app.
            recovery_deadline = time.monotonic() + 25
            while time.monotonic() < recovery_deadline:
                if any(e["event"] == "overlay_added" and e["wallMs"] >= launch_started_at for e in events()[before:]):
                    break
                time.sleep(.5)
            now = int(shell("date", "+%s%3N"))
            if now >= created["end"]:
                raise RuntimeError("Reboot exceeded the active window; no enforcement claim is possible")
            (args.output / f"{method}-reboot-active.png").write_bytes(adb("exec-out", "screencap", "-p", binary=True))
            recovered = events()[before:]
            after_boot = [e for e in recovered if e["elapsedMs"] < created["elapsedMs"]]
            row = dict(method=method, window=created, observedAtMs=now, events=recovered,
                       targetLaunchReturnedAtMs=launched_at,
                       targetLaunchRequestedAtMs=launch_started_at,
                       afterBootEvents=after_boot,
                       persistedWindow=adb("exec-out", "run-as", LAB, "cat", "shared_prefs/experiment.xml"))
            results.append(row)
            row["activeTapRequestedAtMs"] = int(shell("date", "+%s%3N"))
            if row["activeTapRequestedAtMs"] >= created["end"] - 1000:
                raise RuntimeError("No time remains to verify input blocking")
            shell("input", "tap", *tap_point)
            (args.output / "reboot-results.json").write_text(json.dumps(results, ensure_ascii=False, indent=2))
            print(json.dumps(dict(method=method, remainingSeconds=(created["end"] - now) / 1000,
                                  overlayAddedAfterBoot=any(e["event"] == "overlay_added" for e in after_boot))), flush=True)
            # Preserve the no-early-end constraint and test natural expiration.
            while int(shell("date", "+%s%3N")) < created["end"] + 1000:
                time.sleep(5)
            (args.output / f"{method}-reboot-ended.png").write_bytes(adb("exec-out", "screencap", "-p", binary=True))
            shell("input", "tap", *tap_point)
            time.sleep(.5)
            row["events"] = events()[before:]
            row["afterBootEvents"] = [e for e in row["events"] if e["elapsedMs"] < created["elapsedMs"]]
            raw = adb("logcat", "-d", "-v", "raw", "-s", "BearLockProbe:I", "*:S")
            row["probeEvents"] = []
            for line in raw.splitlines():
                match = re.search(r"(resume|pause|tap) wallMs=(\d+) uptimeMs=(\d+) taps=(\d+)", line)
                if match and int(match[2]) >= created["wallMs"]:
                    row["probeEvents"].append(dict(event=match[1], wallMs=int(match[2]), taps=int(match[4])))
            row["tapsDuringLock"] = sum(e["event"] == "tap" and e["wallMs"] < created["end"] for e in row["probeEvents"])
            row["tapsAfterEnd"] = sum(e["event"] == "tap" and e["wallMs"] >= created["end"] for e in row["probeEvents"])
            row["passed"] = (any(e["event"] == "overlay_added" for e in row["afterBootEvents"])
                             and row["tapsDuringLock"] == 0 and row["tapsAfterEnd"] == 1)
            (args.output / "reboot-results.json").write_text(json.dumps(results, ensure_ascii=False, indent=2))
            assert row["passed"], "Reboot recovery or input verification failed; inspect saved evidence"
    finally:
        shell("settings", "put", "secure", "enabled_accessibility_services", original)
        if original_enabled == "null":
            shell("settings", "delete", "secure", "accessibility_enabled")
        else:
            shell("settings", "put", "secure", "accessibility_enabled", original_enabled)


if __name__ == "__main__":
    main()
