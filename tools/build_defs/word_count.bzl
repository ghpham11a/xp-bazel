# Exercise 2 — A rule that wraps a tool (ctx.actions.run).
#
# This rule demonstrates the pattern of wrapping a real executable
# (in this case, a Python script) as a build action. This is the
# same pattern used by protoc rules, lint rules, code generators, etc.
#
# Key new concepts vs Exercise 1:
#   - ctx.actions.run() instead of run_shell() (preferred for real tools)
#   - attr.label(executable=True, cfg="exec") for the tool attribute
#   - ctx.executable.<attr> to get the tool's executable File
#   - ctx.actions.args() to build command-line arguments cleanly
#
# Usage in a BUILD file:
#   load("//tools/build_defs:word_count.bzl", "word_count")
#
#   word_count(
#       name = "my_report",
#       src = "input.txt",
#   )

def _word_count_impl(ctx):
    # ── Step 1: Get the input file ─────────────────────────────────────
    # Same pattern as Exercise 1 — attr.label(allow_single_file=True)
    # gives us ctx.file.src.
    src = ctx.file.src

    # ── Step 2: Declare the output ─────────────────────────────────────
    # The report will be a JSON file.
    out = ctx.actions.declare_file(ctx.label.name + ".json")

    # ── Step 3: Get the tool executable ────────────────────────────────
    #
    # ctx.executable.tool gives us the File object for the tool binary.
    # This works because we declared the "tool" attribute with
    # `executable = True` below.
    #
    # IMPORTANT distinction:
    #   ctx.attr.tool    → the Target object (the dependency itself)
    #   ctx.executable.tool → the executable File within that target
    #   ctx.file.tool    → would be for non-executable single files
    tool = ctx.executable.tool

    # ── Step 4: Build command-line arguments ───────────────────────────
    #
    # ctx.actions.args() creates an Args object — a structured way to
    # build command lines. Prefer this over string formatting because:
    #   1. It handles escaping and quoting automatically
    #   2. It supports param files for very long arg lists
    #   3. It's more readable
    #
    # add() appends a flag and its value. Bazel will render these as
    # separate argv entries: ["--input", "path/to/file", "--output", ...]
    args = ctx.actions.args()
    args.add("--input", src)     # File objects auto-convert to their path
    args.add("--output", out)

    # ── Step 5: Register the action with ctx.actions.run() ─────────────
    #
    # run() vs run_shell():
    #   - run() takes an explicit executable + arguments (preferred)
    #   - run_shell() takes a shell command string (simpler but fragile)
    #
    # Use run() when you have a real tool binary. Use run_shell() only
    # for quick one-liners where spinning up a full tool is overkill.
    #
    # Key parameters:
    #   executable — the tool to run (must be from an exec-cfg attribute)
    #   arguments  — list of Args objects or strings
    #   inputs     — depset or list of input files (the source file here)
    #   tools      — additional tool files needed (handled automatically
    #                when using ctx.executable, but explicit is clearer)
    #   outputs    — files this action produces
    #   mnemonic   — short tag shown in Bazel's progress output
    #                (e.g., "WordCount 1/3")
    ctx.actions.run(
        executable = tool,
        arguments = [args],
        inputs = [src],
        outputs = [out],
        mnemonic = "WordCount",
        progress_message = "Counting words in %s" % src.short_path,
    )

    # ── Step 6: Return DefaultInfo ─────────────────────────────────────
    return [DefaultInfo(files = depset([out]))]

# ─── Rule declaration ──────────────────────────────────────────────────

word_count = rule(
    doc = "Runs a word-count tool on a source file and produces a JSON report. Exercise 2: wrapping a tool.",
    implementation = _word_count_impl,
    attrs = {
        # The source file to analyze.
        "src": attr.label(
            doc = "The file to count words in.",
            allow_single_file = True,
            mandatory = True,
        ),

        # The tool to run — this is the key new concept in Exercise 2.
        #
        # executable = True:
        #   Tells Bazel this attribute points to something runnable.
        #   This enables ctx.executable.tool in the implementation.
        #
        # cfg = "exec":
        #   THIS IS CRITICAL. It tells Bazel to build the tool for the
        #   *execution platform* (the machine running the build), not
        #   the *target platform* (the machine the output runs on).
        #
        #   Why does this matter? When cross-compiling (e.g., building
        #   ARM binaries on an x86 machine):
        #     - cfg = "exec"   → tool is built for x86 (so it can run NOW)
        #     - cfg = "target" → tool is built for ARM (can't run on x86!)
        #
        #   Rule of thumb:
        #     - Tools that RUN DURING THE BUILD → cfg = "exec"
        #     - Things that END UP IN THE OUTPUT → cfg = "target" (default)
        #
        # default = Label(...):
        #   Provides a default tool so users don't have to specify it
        #   every time. They can override it if needed.
        "tool": attr.label(
            doc = "The word-count tool executable.",
            executable = True,
            cfg = "exec",
            default = Label("//tools/build_defs:wordcount_tool"),
        ),
    },
)
