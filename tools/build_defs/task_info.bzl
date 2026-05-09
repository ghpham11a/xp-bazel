# Exercise 3 — A rule with a custom provider.
#
# Providers are how rules communicate data to each other through the
# build graph. Think of them as typed return values: one rule produces
# a provider, and downstream rules that depend on it can read that data.
#
# Built-in providers you've already seen:
#   - DefaultInfo (carries default output files and runfiles)
#
# Here we define our OWN provider: TaskInfo. It carries metadata about
# a "task" in our monorepo (language, description, source count).
# Then we define TWO rules:
#   - task_info:    produces a TaskInfo provider
#   - task_summary: consumes TaskInfo from its deps and writes a report
#
# This producer/consumer pattern is the foundation of how Bazel rulesets
# work. For example, in rules_go:
#   - go_library produces GoLibrary provider (import path, source list)
#   - go_binary consumes GoLibrary from its deps to link the final binary
#
# Usage in a BUILD file:
#   load("//tools/build_defs:task_info.bzl", "task_info", "task_summary")
#
#   task_info(name = "go_info", language = "go", description = "Go backend")
#   task_info(name = "py_info", language = "python", description = "Python scripts")
#
#   task_summary(
#       name = "all_tasks",
#       deps = [":go_info", ":py_info"],
#   )

# ─── Step 1: Define the provider ──────────────────────────────────────
#
# provider() creates a new provider type — like defining a struct or
# a class in other languages. The `fields` dict declares what data
# the provider carries, with documentation for each field.
#
# After this call, TaskInfo is a constructor AND a type:
#   - TaskInfo(language="go", ...) creates an instance
#   - You can check if a target has it: TaskInfo in target_info
#
# Providers are IMMUTABLE once created — you can't modify them after
# construction. This is by design: it ensures the build graph is
# deterministic.

TaskInfo = provider(
    doc = "Carries metadata about a task in the monorepo.",
    fields = {
        "language": "String: the programming language (e.g., 'go', 'python').",
        "description": "String: a human-readable description of the task.",
        "source_count": "Int: number of source files in this task.",
    },
)

# ─── Step 2: The producer rule — task_info ─────────────────────────────
#
# This rule creates and returns a TaskInfo provider. It doesn't produce
# any output files — its only purpose is to carry metadata through the
# build graph.
#
# Not all rules produce files! Many exist solely to produce providers
# that other rules consume. This is a common pattern in Bazel.

def _task_info_impl(ctx):
    # Count the source files provided via the srcs attribute.
    # ctx.files.srcs returns a list of File objects.
    source_count = len(ctx.files.srcs)

    # ── Create the provider instance ───────────────────────────────
    #
    # We construct a TaskInfo with the data from our attributes.
    # This is what downstream rules will receive when they depend on us.
    info = TaskInfo(
        language = ctx.attr.language,
        description = ctx.attr.description,
        source_count = source_count,
    )

    # ── Return multiple providers ──────────────────────────────────
    #
    # A rule can return MULTIPLE providers in its list. Here we return:
    #   - TaskInfo: our custom provider (carries metadata)
    #   - DefaultInfo: the built-in provider (no files, since this rule
    #     doesn't produce any output files)
    #
    # Returning DefaultInfo with no files is fine — it just means
    # `bazel build` on this target won't produce visible output.
    return [
        info,
        DefaultInfo(),
    ]

task_info = rule(
    doc = "Declares metadata about a task. Produces a TaskInfo provider. Exercise 3: custom providers.",
    implementation = _task_info_impl,
    attrs = {
        "language": attr.string(
            doc = "The programming language for this task.",
            mandatory = True,
        ),
        "description": attr.string(
            doc = "A human-readable description of the task.",
            mandatory = True,
        ),
        # srcs is optional — we use it to count source files.
        # allow_files = True means any file type is accepted.
        "srcs": attr.label_list(
            doc = "Source files belonging to this task (used for counting).",
            allow_files = True,
            default = [],
        ),
    },
)

# ─── Step 3: The consumer rule — task_summary ──────────────────────────
#
# This rule CONSUMES TaskInfo providers from its dependencies and
# produces a summary report file. This demonstrates the key concept:
# one rule reading another rule's provider.

def _task_summary_impl(ctx):
    # ── Declare the output file ────────────────────────────────────
    out = ctx.actions.declare_file(ctx.label.name + ".txt")

    # ── Collect TaskInfo from each dependency ──────────────────────
    #
    # ctx.attr.deps is a list of Target objects (the deps attribute).
    # For each dep, we check if it provides TaskInfo and extract it.
    #
    # dep[TaskInfo] reads the TaskInfo provider from the target.
    # This is like dict access — it will fail if the target doesn't
    # have TaskInfo. That's why we guard with `if TaskInfo in dep`.
    #
    # In production rulesets, you'd typically use `providers = [TaskInfo]`
    # on the attr to enforce this at analysis time (see the attrs below).
    lines = ["Task Summary Report", "=" * 40, ""]
    for dep in ctx.attr.deps:
        if TaskInfo in dep:
            info = dep[TaskInfo]
            lines.append("Task: %s" % dep.label.name)
            lines.append("  Language:     %s" % info.language)
            lines.append("  Description:  %s" % info.description)
            lines.append("  Source files: %d" % info.source_count)
            lines.append("")

    lines.append("Total tasks: %d" % len(ctx.attr.deps))

    # ── Write the report ───────────────────────────────────────────
    #
    # ctx.actions.write() is perfect for generating small text files
    # from data you already have in memory (no external tool needed).
    # For anything that processes input files, use run() or run_shell().
    ctx.actions.write(
        output = out,
        content = "\n".join(lines) + "\n",
    )

    return [DefaultInfo(files = depset([out]))]

task_summary = rule(
    doc = "Consumes TaskInfo providers from deps and writes a summary report. Exercise 3: consuming providers.",
    implementation = _task_summary_impl,
    attrs = {
        # deps is a label_list — a list of targets this rule depends on.
        #
        # providers = [TaskInfo] is a constraint: Bazel will reject any
        # dep that doesn't provide TaskInfo at analysis time, before
        # any actions run. This gives you a clear error message like:
        #   "'//foo:bar' does not have mandatory providers: 'TaskInfo'"
        #
        # This is much better than a confusing runtime KeyError.
        "deps": attr.label_list(
            doc = "task_info targets to summarize.",
            providers = [TaskInfo],
            mandatory = True,
        ),
    },
)
