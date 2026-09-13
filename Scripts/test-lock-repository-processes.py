#!/usr/bin/env python3
"""Exercise real cross-process JSON transactions on Linux and macOS, not just actors."""
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
    harness = directory / "Writer.swift"
    harness.write_text('''import Foundation
@main struct Writer {
    static func main() async throws {
        let repository = JSONFileLockRepository(fileURL: URL(fileURLWithPath: CommandLine.arguments[1]))
        let store = LockStore(repository: repository)
        for _ in 0..<40 {
            _ = try await store.saveTargetSelection(LockTargetSelectionRef())
        }
    }
}
''')
    executable = directory / "writer"
    subprocess.run([swiftc, *map(str, sorted((root / "Sources/BearLockCore").glob("*.swift"))),
                    str(harness), "-o", str(executable)], check=True, timeout=120)
    state_path = directory / "state.json"
    processes = [subprocess.Popen([str(executable), str(state_path)]) for _ in range(4)]
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
    assert len(targets) == 160, f"Lost updates: {len(targets)} of 160 survived"
    assert len({target["id"] for target in targets}) == 160
    assert state["selectedTargetID"] == targets[-1]["id"], "Selected target and saved data diverged"
    print("PASS: 4 independent processes preserved all 160 updates and the matching selected target ID")
