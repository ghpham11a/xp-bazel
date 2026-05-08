import subprocess
import os
import glob


def find_binary(rlocation):
    """Find a Bazel binary using the runfiles directory."""
    runfiles_dir = os.environ.get("RUNFILES_DIR")
    if not runfiles_dir:
        runfiles_dir = os.path.join(os.path.dirname(__file__), "..", "..")
    path = os.path.normpath(os.path.join(runfiles_dir, rlocation))
    if os.path.exists(path):
        return path
    return None


def find_in_bazel_out(subpath):
    """Find a binary in the Bazel output tree by searching the user's output base."""
    home = os.path.expanduser("~")
    pattern = os.path.join(home, "_bazel_*", "*", "execroot", "_main",
                           "bazel-out", "*", "bin", subpath)
    matches = glob.glob(pattern)
    if matches:
        return matches[0]
    return None


# Tasks that work from runfiles (self-contained executables)
RUNFILE_TASKS = [
    ("Java", "_main/java-task/main.exe"),
    ("Go", "_main/go-task/go_bin_/go_bin.exe"),
    ("Python", "_main/python-task/main.exe"),
    ("C++", "_main/cpp-task/main.exe"),
]

# Tasks that need their full runfiles tree (found via bazel output base)
BAZEL_OUT_TASKS = [
    ("JavaScript", "js-task/main_/main.bat"),
    ("C#", "csharp-task/program/net9.0/program.dll.bat"),
]


def run_task(name, cmd):
    print(f"[{name}] Running...")
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=30,
        )
        for line in result.stdout.strip().splitlines():
            print(f"[{name}]   {line}")
        if result.returncode != 0:
            print(f"[{name}] FAILED (exit code {result.returncode})")
            if result.stderr:
                for line in result.stderr.strip().splitlines()[-5:]:
                    print(f"[{name}]   {line}")
            return False
        print(f"[{name}] OK")
        return True
    except Exception as e:
        print(f"[{name}] ERROR: {e}")
        return False


if __name__ == "__main__":
    print("=== Task Orchestrator ===\n")
    results = []

    for name, rlocation in RUNFILE_TASKS:
        binary = find_binary(rlocation)
        if not binary:
            print(f"[{name}] ERROR: binary not found at {rlocation}\n")
            results.append((name, False))
            continue
        success = run_task(name, [binary])
        results.append((name, success))
        print()

    for name, subpath in BAZEL_OUT_TASKS:
        binary = find_in_bazel_out(subpath)
        if not binary:
            print(f"[{name}] ERROR: binary not found in bazel output tree\n")
            results.append((name, False))
            continue
        success = run_task(name, [binary])
        results.append((name, success))
        print()

    print("=== Summary ===")
    for name, success in results:
        status = "PASS" if success else "FAIL"
        print(f"  {name}: {status}")

    failures = sum(1 for _, s in results if not s)
    if failures:
        print(f"\n{failures} task(s) failed.")
        exit(1)
    else:
        print(f"\nAll {len(results)} tasks completed successfully.")
