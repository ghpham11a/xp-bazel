```bash
# Build & Run
bazel run //task-orchestrator:main

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
```