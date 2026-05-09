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

# Build configs (--config=<name>)
bazel build //... --config=debug   # debug symbols, no stripping
bazel build //... --config=ci      # CI mode: keep going, no cache uploads
bazel build //cpp-task/... --config=asan  # AddressSanitizer (C/C++ only)
```
