```bash
# Build & Run
bazel run //task-orchestrator:main
bazel build //...

# Build & Run individual tasks
bazel run //java-task:main
bazel run //go-task:go_bin
bazel run //js-task:main
bazel run //python-task:main
bazel run //csharp-task:program
bazel run //cpp-task:main

# Tests
bazel test //java:main_test
bazel test //go:go_test
bazel test //js-task:main_test
bazel test //python:main_test
bazel test //csharp:program_test
bazel test //cpp-task:main_test

# All tests at once
bazel test //...

# Word count reports (Module 10 custom rule)
bazel build //go-task:main_word_count
bazel build //python-task:main_word_count
bazel build //cpp-task:main_word_count

# Module 10 exercises (custom rules & providers)
bazel build //tools/build_defs/...

# Module 11 — Aspects
# Build the project manifest (walks C++ and Go dep graphs)
bazel build //tools/aspects:project_manifest
# Build just the C++ manifest
bazel build //tools/aspects:cpp_manifest
# Apply the aspect ad-hoc to any target (no BUILD changes needed)
bazel build //cpp-task:main --aspects=//tools/aspects:target_info.bzl%target_info_aspect --output_groups=target_info_files

# Module 12 — Build Performance: Caching, Sandboxing, Workers
# 1. Clean build with profiling (produces a Chrome-tracing profile)
bazel clean
bazel build //... --profile=profile.gz
# Open profile.gz at https://ui.perfetto.dev to visualize where time goes

# 2. Incremental build with profiling (touch one file, rebuild)
# Compare this profile to the clean build — should be much faster
touch cpp-task/main.cc
bazel build //... --profile=profile_incremental.gz

# 3. Disable persistent workers (compilers restart every action — slower)
bazel build //... --worker_sandboxing=false --strategy=Javac=local

# 4. Disable sandboxing (actions can see undeclared inputs — unsafe!)
bazel build //... --spawn_strategy=local
# Re-enable by omitting the flag (sandboxing is the default)

# 5. Inspect cache and build info
bazel info output_base       # where Bazel stores cache and build artifacts
bazel info execution_root    # the sandbox root for actions

# Build configs (--config=<name>)
bazel build //... --config=debug   # debug symbols, no stripping
bazel build //... --config=ci      # CI mode: keep going, no cache uploads
bazel build //cpp-task/... --config=asan  # AddressSanitizer (C/C++ only)
```
