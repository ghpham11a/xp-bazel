# Exercise 1 — A trivial custom rule: prepend a header to a file.
#
# This is the simplest possible Bazel rule. It demonstrates the core
# anatomy that EVERY rule shares:
#
#   1. An implementation function that receives `ctx` (the rule context)
#   2. Declaring output files with ctx.actions.declare_file()
#   3. Registering an action (the shell command Bazel will execute)
#   4. Returning providers (at minimum, DefaultInfo with the output files)
#
# Usage in a BUILD file:
#   load("//tools/build_defs:header_file.bzl", "header_file")
#
#   header_file(
#       name = "my_file_with_header",
#       src = "input.txt",
#       header = "# Copyright 2026 My Company. All rights reserved.",
#   )

# ─── Implementation function ───────────────────────────────────────────
#
# Every rule has exactly one implementation function. Bazel calls it
# during the *analysis phase* (before any commands run). Its job is to:
#   - Declare what files will be produced
#   - Register actions (commands) that produce those files
#   - Return providers describing the outputs
#
# The `ctx` parameter is a rule context object — your gateway to
# everything: the rule's attributes, actions API, label info, etc.
# Docs: https://bazel.build/rules/lib/builtins/ctx

def _header_file_impl(ctx):
    # ── Step 1: Access the input file ──────────────────────────────────
    #
    # ctx.file.src gives us a single File object because we declared
    # the "src" attribute with `allow_single_file = True` below.
    #
    # If we had used attr.label_list(), we'd use ctx.files.srcs instead,
    # which returns a list of File objects.
    src = ctx.file.src

    # ── Step 2: Declare the output file ────────────────────────────────
    #
    # ctx.actions.declare_file() tells Bazel "this action will produce
    # a file with this name." Bazel needs to know ALL outputs up front
    # (during analysis) so it can build the action graph before executing
    # anything.
    #
    # ctx.label.name is the `name` attribute from the BUILD file target.
    # We use it to derive the output filename, preserving the extension
    # from the input file.
    #
    # IMPORTANT: declare_file() does NOT create the file — it just
    # reserves the name. The action below is what actually creates it.
    extension = src.basename.split(".")[-1] if "." in src.basename else "txt"
    out = ctx.actions.declare_file(ctx.label.name + "." + extension)

    # ── Step 3: Get the header text ────────────────────────────────────
    #
    # ctx.attr.header gives us the string value of the "header" attribute
    # defined in the rule's attrs dict below.
    header = ctx.attr.header

    # ── Step 4: Register an action ─────────────────────────────────────
    #
    # ctx.actions.run_shell() registers a shell command for Bazel to run
    # during the *execution phase*. This is the most flexible action type
    # but also the least portable (shell syntax varies across OSes).
    #
    # Key parameters:
    #   outputs — files this action creates (MUST match declare_file calls)
    #   inputs  — files this action reads (Bazel enforces this via sandbox)
    #   command — the shell command string
    #
    # CRITICAL RULE: Every file your action reads MUST be in `inputs`.
    # Every file it writes MUST be in `outputs`. If you cheat:
    #   - Sandboxing will catch you locally (the file won't be visible)
    #   - Remote execution will definitely catch you
    #
    # The printf + cat pattern: we write the header line, then append
    # the original file contents. This is a simple, portable approach.
    ctx.actions.run_shell(
        outputs = [out],
        inputs = [src],
        command = "printf '%s\\n' '{header}' > {output} && cat {input} >> {output}".format(
            header = header,
            output = out.path,
            input = src.path,
        ),
    )

    # ── Step 5: Return providers ───────────────────────────────────────
    #
    # Every rule MUST return a list of providers. Providers are typed
    # bundles of data that flow from a target to its dependents (reverse
    # dependencies) in the build graph.
    #
    # DefaultInfo is the built-in provider that carries:
    #   - files: the default outputs (what `bazel build` will build)
    #   - runfiles: files needed at runtime (not relevant here)
    #
    # depset() wraps our output file in a depset — a memory-efficient
    # set structure designed for the build graph. Even for a single file,
    # DefaultInfo expects a depset, not a plain list.
    #
    # We'll learn more about depset in Exercise 4.
    return [DefaultInfo(files = depset([out]))]

# ─── Rule declaration ──────────────────────────────────────────────────
#
# rule() creates the actual rule that BUILD files can call. It connects:
#   - implementation: the function above
#   - attrs: the schema of attributes the rule accepts
#
# Think of it like defining a function signature:
#   - The implementation is the function body
#   - The attrs are the parameters with their types
#
# Attribute types (attr.*):
#   - attr.label()       → a dependency on another target or file
#   - attr.label_list()  → a list of dependencies
#   - attr.string()      → a string value
#   - attr.int()         → an integer
#   - attr.bool()        → a boolean
#   - attr.string_list() → a list of strings
#   ... and more: https://bazel.build/rules/lib/builtins/attr

header_file = rule(
    # Docstring — shown in `bazel query --output=build` and documentation tools.
    doc = "Copies a file with a header line prepended. Exercise 1: the simplest custom rule.",

    # The implementation function Bazel calls during analysis.
    implementation = _header_file_impl,

    # Attribute schema — what the BUILD file must/can provide.
    attrs = {
        # "src" is a label attribute pointing to a single file.
        #
        # allow_single_file = True means:
        #   1. The attribute accepts file targets (not just rule targets)
        #   2. It must resolve to exactly one file
        #   3. We can use ctx.file.src (singular) in the implementation
        #
        # mandatory = True means the BUILD file MUST provide this attribute.
        "src": attr.label(
            doc = "The source file to prepend the header to.",
            allow_single_file = True,
            mandatory = True,
        ),

        # "header" is a simple string attribute with a default value.
        # If the BUILD file doesn't specify it, this default is used.
        "header": attr.string(
            doc = "The header line to prepend to the file.",
            default = "# Generated by Bazel — do not edit.",
        ),
    },
)
