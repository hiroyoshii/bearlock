#!/usr/bin/env python3
"""Bounded emulator comparison. Installs are separate. Does not clear device data/logcat.

Usage: python3 scripts/compare.py --adb /path/to/adb --serial emulator-5554 --output ../artifacts/android-comparison
Grants lab-only appops and temporarily enables the lab accessibility service for B.
Restores the original accessibility service list and Doze state on exit.
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
    p.add_argument("--output", type=Path, required=True)
    p.add_argument("--method", choices=["USAGE", "ACCESSIBILITY", "BOTH"], default="BOTH")
    args = p.parse_args()
    if not args.serial.startswith("emulator-"):
        p.error("This harness changes test settings; use an emulator serial.")
    args.output.mkdir(parents=True, exist_ok=True)

    def adb(*cmd, binary=False, check=True):
        r = subprocess.run([args.adb, "-s", args.serial, *cmd], capture_output=True, timeout=35)
        if check and r.returncode:
            raise RuntimeError(r.stderr.decode(errors="replace") + r.stdout.decode(errors="replace"))
        return r.stdout if binary else r.stdout.decode(errors="replace").strip()

    def shell(*cmd):
        return adb("shell", *map(str, cmd))

    def events():
        raw = adb("exec-out", "run-as", LAB, "cat", "files/events.jsonl", check=False)
        return [json.loads(line) for line in raw.splitlines() if line.startswith("{")]

    def screenshot(name):
        (args.output / f"{name}.png").write_bytes(adb("exec-out", "screencap", "-p", binary=True))

    def nodes():
        shell("uiautomator", "dump", "/sdcard/bearlock-lab-window.xml")
        return ET.fromstring(shell("cat", "/sdcard/bearlock-lab-window.xml")).iter("node")

    def center(node):
        x1, y1, x2, y2 = map(int, re.findall(r"\d+", node.attrib["bounds"]))
        return (x1 + x2) // 2, (y1 + y2) // 2

    original_services = shell("settings", "get", "secure", "enabled_accessibility_services")
    original_enabled = shell("settings", "get", "secure", "accessibility_enabled")
    results = []
    try:
        for op in ["GET_USAGE_STATS", "SYSTEM_ALERT_WINDOW", "SCHEDULE_EXACT_ALARM"]:
            shell("appops", "set", LAB, op, "allow")
        shell("pm", "grant", LAB, "android.permission.POST_NOTIFICATIONS")
        shell("input", "keyevent", "KEYCODE_WAKEUP")
        shell("input", "keyevent", "82")
        shell("am", "start", "-n", f"{PROBE}/.ProbeActivity")
        time.sleep(1)
        probe_nodes = list(nodes())
        tap_point = center(next(n for n in probe_nodes if n.attrib.get("text", "").startswith("タップ試験")))
        switch = next(n for n in probe_nodes if n.attrib.get("class") == "android.widget.Switch")
        switch_point = center(switch)
        if switch.attrib.get("checked") == "true":
            shell("input", "tap", *switch_point)

        methods = ["USAGE", "ACCESSIBILITY"] if args.method == "BOTH" else [args.method]
        for method in methods:
            existing = [s for s in original_services.split(":") if s not in ["", "null", SERVICE]]
            if method == "ACCESSIBILITY":
                existing.append(SERVICE)
            shell("settings", "put", "secure", "enabled_accessibility_services", ":".join(existing) or "null")
            shell("settings", "put", "secure", "accessibility_enabled", "1" if existing else "0")
            time.sleep(2)
            for scenario in ["launch-1", "launch-2", "launch-3", "scheduled-open", "screen-off", "reject-overlay"]:
                shell("am", "start", "-n", f"{PROBE}/.ProbeActivity")
                if scenario == "reject-overlay":
                    shell("input", "tap", *switch_point)
                shell("input", "keyevent", "KEYCODE_HOME")
                time.sleep(.5)
                before = len(events())
                delay = 8 if scenario in ["scheduled-open", "screen-off"] else 0
                duration = 12
                shell("am", "start", "-W", "-n", f"{LAB}/.ExperimentActivity", "--es", "method", method,
                      "--ei", "delay", delay, "--ei", "duration", duration)
                created = next((e for e in events()[before:] if e["event"] == "created"), None)
                if not created:
                    raise RuntimeError(f"Experiment did not start: {events()[before:]}")
                shell("am", "start", "-W", "-n", f"{PROBE}/.ProbeActivity")
                if scenario == "screen-off":
                    shell("dumpsys", "battery", "unplug")
                    shell("input", "keyevent", "KEYCODE_SLEEP")
                    idle_result = shell("dumpsys", "deviceidle", "force-idle")
                    if not ("now forced" in idle_result.lower() and "idle" in idle_result.lower()):
                        raise RuntimeError(f"Doze not confirmed: {idle_result}")
                    time.sleep(delay + 1)
                    shell("dumpsys", "deviceidle", "unforce")
                    shell("input", "keyevent", "KEYCODE_WAKEUP")
                    shell("input", "keyevent", "82")
                elif delay:
                    time.sleep(delay + 1)
                else:
                    time.sleep(1)
                screenshot(f"{method}-{scenario}-active")
                active_tap_time = int(shell("date", "+%s%3N"))
                if not created["start"] <= active_tap_time < created["end"] - 500:
                    raise RuntimeError("Active tap missed the experiment window; increase duration and rerun.")
                shell("input", "tap", *tap_point)
                # Wait for the actual saved end, keeping any single sleep below 30 seconds.
                device_now = int(shell("date", "+%s")) * 1000
                time.sleep(max(0, min(30, (created["end"] - device_now) / 1000 + 1.5)))
                shell("input", "tap", *tap_point)
                screenshot(f"{method}-{scenario}-ended")
                relevant = events()[before:]
                raw_probe = adb("logcat", "-d", "-v", "raw", "-s", "BearLockProbe:I", "*:S")
                probe_events = []
                for line in raw_probe.splitlines():
                    match = re.search(r"(resume|pause|tap) wallMs=(\d+) uptimeMs=(\d+) taps=(\d+)", line)
                    if match and int(match[2]) >= created["wallMs"]:
                        probe_events.append(dict(event=match[1], wallMs=int(match[2]), uptimeMs=int(match[3]), taps=int(match[4])))
                row = dict(method=method, scenario=scenario, window=created, events=relevant, probeEvents=probe_events,
                           activeTapRequestedAtMs=active_tap_time,
                           tapsDuringLock=sum(e["event"] == "tap" and created["start"] <= e["wallMs"] < created["end"] for e in probe_events),
                           tapsAfterEnd=sum(e["event"] == "tap" and e["wallMs"] >= created["end"] for e in probe_events))
                results.append(row)
                (args.output / "results.json").write_text(json.dumps(results, ensure_ascii=False, indent=2))
                print(json.dumps({k: row[k] for k in ["method", "scenario", "tapsDuringLock", "tapsAfterEnd"]}), flush=True)
                if scenario == "reject-overlay":
                    shell("input", "tap", *switch_point)
                if scenario == "screen-off":
                    shell("dumpsys", "battery", "reset")
    finally:
        shell("dumpsys", "deviceidle", "unforce")
        shell("dumpsys", "battery", "reset")
        shell("settings", "put", "secure", "enabled_accessibility_services", original_services)
        if original_enabled == "null":
            shell("settings", "delete", "secure", "accessibility_enabled")
        else:
            shell("settings", "put", "secure", "accessibility_enabled", original_enabled)


if __name__ == "__main__":
    main()
