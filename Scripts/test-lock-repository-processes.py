#!/usr/bin/env python3
"""Exercise one atomic writer with real cross-process readers on Linux and macOS."""
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
swiftc = shutil.which("swiftc")
if not swiftc:
    raise SystemExit("swiftc is required")
with tempfile.TemporaryDirectory(prefix="bearlock-process-test-") as temporary:
    directory = Path(temporary)
    harness = directory / "Harness.swift"
    harness.write_text('''import Foundation
@main struct Harness {
    static func main() async throws {
        let repository = JSONFileLockRepository(fileURL: URL(fileURLWithPath: CommandLine.arguments[1]))
        switch CommandLine.arguments[2] {
        case "seed":
            try repository.save(LockState())
        case "write":
            let store = LockStore(repository: repository)
            for _ in 0..<200 {
                _ = try await store.saveTargetSelection(LockTargetSelectionRef())
            }
        default:
            for _ in 0..<2_000 {
                let state = try repository.load()
                if let selected = state.selectedTargetID,
                   !state.targetSelections.contains(where: { $0.id == selected }) {
                    throw CocoaError(.fileReadCorruptFile)
                }
            }
        }
    }
}
''')
    executable = directory / "harness"
    subprocess.run([swiftc, *map(str, sorted((root / "Sources/BearLockCore").glob("*.swift"))),
                    str(harness), "-o", str(executable)], check=True, timeout=120)
    state_path = directory / "state.json"
    subprocess.run([str(executable), str(state_path), "seed"], check=True, timeout=30)
    processes = [subprocess.Popen([str(executable), str(state_path), "write"])]
    processes += [subprocess.Popen([str(executable), str(state_path), "read"]) for _ in range(4)]
    try:
        for process in processes:
            if process.wait(timeout=60) != 0:
                raise AssertionError("Writer process failed")
    finally:
        for process in processes:
            if process.poll() is None:
                process.kill()
                process.wait()
    state = json.loads(state_path.read_text())
    targets = state["targetSelections"]
    assert len(targets) == 200, f"Writer lost updates: {len(targets)} of 200 survived"
    assert len({target["id"] for target in targets}) == 200
    assert state["selectedTargetID"] == targets[-1]["id"], "Selected target and saved data diverged"
    print("PASS: one writer published 200 atomic snapshots to four lock-free readers")
