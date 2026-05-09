# =========================================================================
# Module 11 — Aspects
# =========================================================================
#
# WHAT IS AN ASPECT?
# ──────────────────
# An aspect is like a "rule that piggybacks on existing targets." Instead
# of defining new targets, an aspect VISITS existing ones and adds behavior.
#
# Think of it this way:
#   - A rule says: "here's how to BUILD something."
#   - An aspect says: "for every target that already exists, here's some
#     EXTRA work I want to do."
#
# WHY NOT JUST USE RULES?
# ───────────────────────
# Without aspects, if you wanted to run a linter on every cc_library in
# your repo, you'd have two bad options:
#   1. Modify cc_library's definition (you can't — it's a built-in rule)
#   2. Add a lint_cc_library() target next to every cc_library (tedious,
#      easy to forget, doesn't scale)
#
# Aspects solve this: you write ONE aspect, and Bazel automatically
# applies it to every target in the dependency graph. The original
# targets don't need to know or care.
#
# REAL-WORLD USES:
#   - IDE plugins (IntelliJ, VS Code) use aspects to extract compile
#     commands, source files, and dependencies from every target
#   - Linters use aspects to run checks on every library target
#   - License checkers use aspects to collect license info transitively
#   - Dependency graph exporters for security scanning
#
# HOW THIS FILE IS ORGANIZED:
#   1. Provider definition — the data structure our aspect produces
#   2. Aspect implementation — the function that runs on each target
#   3. Aspect declaration — the aspect() object itself
#   4. Aggregator rule — collects aspect output into a single manifest
# =========================================================================

# ─────────────────────────────────────────────────────────────────────────
# Step 1: Define a provider for the aspect's output
# ─────────────────────────────────────────────────────────────────────────
#
# Just like custom rules (Module 10), aspects communicate via providers.
# This provider carries the JSON file that our aspect generates for each
# target it visits, plus a depset to accumulate files transitively.
#
# Why a depset for "transitive_infos"?
# The aspect visits targets at every level of the dep graph. We need to
# collect ALL the JSON files from ALL visited targets efficiently.
# As we learned in Module 10 (depsets), a depset avoids O(n²) memory
# by storing references instead of copying lists at each level.

TargetInfoAspectProvider = provider(
    doc = """Carries target metadata collected by the target_info aspect.

    Each visited target gets its own JSON file (in 'info_file'), and
    'transitive_infos' accumulates all JSON files from the entire
    transitive dep subgraph below this target.""",
    fields = {
        "info_file": "File: the JSON metadata file for THIS target",
        "transitive_infos": "depset of Files: all JSON files from this target and its transitive deps",
    },
)

# ─────────────────────────────────────────────────────────────────────────
# Step 2: Implement the aspect
# ─────────────────────────────────────────────────────────────────────────
#
# This function runs once for each target the aspect visits.
# It receives:
#   - target: the target being visited (read-only — you can inspect it
#             but never modify it)
#   - ctx: the aspect's context (similar to a rule's ctx, but scoped
#          to the aspect, not the target)
#
# KEY DIFFERENCE FROM RULES:
#   In a rule implementation, ctx.attr gives you the rule's own attributes.
#   In an aspect implementation, ctx.rule.attr gives you the VISITED
#   TARGET's attributes. The aspect doesn't define its own targets —
#   it's borrowing someone else's.

def _target_info_aspect_impl(target, ctx):
    # ── Collect info about the target we're visiting ──────────────
    #
    # ctx.rule.kind tells us what rule created this target.
    # For example: "cc_library", "cc_binary", "go_library", etc.
    # This is a string, not the rule object itself.
    rule_kind = ctx.rule.kind

    # ctx.label is the full label of the target, like "//cpp-task:main_lib".
    # We convert it to a string for the JSON output.
    label = str(ctx.label)

    # ── Extract source files from the target ──────────────────────
    #
    # Most language rules have a "srcs" attribute, but not all targets
    # do (e.g., alias, filegroup might not). We use hasattr() to safely
    # check before accessing it.
    #
    # ctx.rule.attr.srcs gives us the TARGET's srcs attribute — remember,
    # ctx.rule.attr accesses the visited target's attributes, not the
    # aspect's own attributes.
    #
    # Each src is a Target object. We extract the file paths from each
    # one. A single src entry can expand to multiple files (e.g., a
    # filegroup or glob), so we iterate through each target's files.
    srcs = []
    if hasattr(ctx.rule.attr, "srcs"):
        for src_target in ctx.rule.attr.srcs:
            for f in src_target.files.to_list():
                srcs.append(f.short_path)

    # ── Extract dependencies ──────────────────────────────────────
    #
    # Similarly, most rules have a "deps" attribute. We collect the
    # labels of all direct dependencies.
    #
    # We also check "embed" — Go rules use embed instead of deps for
    # the primary library that a go_binary wraps. Without checking
    # embed, we'd miss the go_library → go_binary connection.
    # This is a great example of why aspects need to be aware of
    # language-specific conventions.
    deps = []
    for attr_name in ["deps", "embed"]:
        if hasattr(ctx.rule.attr, attr_name):
            for dep in getattr(ctx.rule.attr, attr_name):
                deps.append(str(dep.label))

    # ── Generate the JSON output file ─────────────────────────────
    #
    # ctx.actions.declare_file() works the same as in rules.
    # We name the file based on the target name to avoid collisions.
    # The "_target_info.json" suffix makes it clear what generated it.
    info_file = ctx.actions.declare_file(
        "{}_target_info.json".format(ctx.label.name),
    )

    # Build the JSON content. We use manual string formatting here
    # because Starlark doesn't have a json.dumps() function.
    # (In production, you'd use a tool or a more robust approach.)
    #
    # The JSON includes:
    #   - label: the full target label (e.g., "//cpp-task:main_lib")
    #   - rule_kind: what type of rule (e.g., "cc_library")
    #   - srcs: list of source file paths
    #   - deps: list of dependency labels
    json_content = json.encode({
        "label": label,
        "rule_kind": rule_kind,
        "srcs": srcs,
        "deps": deps,
    })

    # Write the JSON to the output file.
    # ctx.actions.write() is the simplest action — it just writes a
    # string to a file. No external tool needed.
    ctx.actions.write(
        output = info_file,
        content = json_content,
    )

    # ── Collect transitive info files via depset ──────────────────
    #
    # This is where the "walking the dep graph" magic happens.
    #
    # For each dependency that our aspect has ALREADY visited (remember,
    # aspects propagate depth-first), we grab its TargetInfoAspectProvider
    # and include its transitive_infos in our own depset.
    #
    # This means if we're visiting target A which depends on B and C:
    #   - B's transitive_infos already contains B's file + all of B's deps' files
    #   - C's transitive_infos already contains C's file + all of C's deps' files
    #   - A's transitive_infos = depset([A's file], transitive=[B's depset, C's depset])
    #
    # At the top of the graph, we have ALL files from ALL targets,
    # accumulated efficiently via depsets (no list copying at each level).
    transitive = []
    for attr_name in ["deps", "embed"]:
        if hasattr(ctx.rule.attr, attr_name):
            for dep in getattr(ctx.rule.attr, attr_name):
                # Not every dependency will have our provider — only those
                # that the aspect actually visited. External deps or deps
                # without the right attributes might not have it.
                if TargetInfoAspectProvider in dep:
                    transitive.append(dep[TargetInfoAspectProvider].transitive_infos)

    transitive_infos = depset(
        direct = [info_file],
        transitive = transitive,
    )

    # ── Return the provider ───────────────────────────────────────
    #
    # Aspects return a list of providers, just like rules.
    # We also include OutputGroupInfo so that the aspect's output files
    # can be requested directly from the command line using:
    #   bazel build //some:target --aspects=//tools/aspects:target_info.bzl%target_info_aspect \
    #       --output_groups=target_info_files
    #
    # OutputGroupInfo is a built-in provider that tells Bazel "these files
    # are available as a named output group." Without it, the JSON files
    # would be generated but not easily accessible from the command line.
    return [
        TargetInfoAspectProvider(
            info_file = info_file,
            transitive_infos = transitive_infos,
        ),
        OutputGroupInfo(
            target_info_files = transitive_infos,
        ),
    ]

# ─────────────────────────────────────────────────────────────────────────
# Step 3: Declare the aspect
# ─────────────────────────────────────────────────────────────────────────
#
# This is where we tell Bazel:
#   1. WHAT function to run on each target (_target_info_aspect_impl)
#   2. WHICH edges to follow (attr_aspects = ["deps", "embed"])
#
# attr_aspects is the key concept:
#   - ["deps"] means: "when you visit a target, also visit everything
#     in its 'deps' attribute, recursively."
#   - ["embed"] is needed for Go rules — go_binary uses "embed" to
#     reference its go_library, not "deps". Without this, the aspect
#     would stop at go_binary and never see the go_library beneath it.
#   - You could follow other edges too: ["deps", "srcs"] would visit
#     source filegroups. ["data"] would follow test data deps.
#   - The aspect propagates depth-first: it visits the leaves of the
#     dep graph first, then works its way back up. This is why we can
#     rely on deps already having TargetInfoAspectProvider when we
#     collect transitive_infos.
#
# IMPORTANT: the aspect visits ALL targets reachable through the listed
# attributes, regardless of what rule created them. It will visit
# cc_library, go_library, java_library, custom rules — everything.
# Your impl function should handle any rule kind gracefully (which ours
# does, since we use hasattr() to check for optional attributes).

target_info_aspect = aspect(
    implementation = _target_info_aspect_impl,
    # Follow these attribute edges to propagate through the graph.
    # "deps" covers most rules. "embed" is needed for Go rules, where
    # go_binary embeds a go_library rather than depending on it.
    # This is what makes aspects powerful — one declaration, and Bazel
    # walks the entire dependency tree for you.
    attr_aspects = ["deps", "embed"],
    doc = """Walks the dependency graph and produces a JSON metadata file
    for each target it visits. The JSON includes the target's label,
    rule kind, source files, and direct dependencies.""",
)

# ─────────────────────────────────────────────────────────────────────────
# Step 4: Aggregator rule — combine all aspect outputs into one manifest
# ─────────────────────────────────────────────────────────────────────────
#
# The aspect produces one JSON file per target. That's useful, but often
# you want a SINGLE combined file — a manifest of your entire project.
#
# This rule:
#   1. Declares the aspect on its "deps" attribute (so visiting any dep
#      automatically triggers the aspect on the entire subgraph)
#   2. Collects all the JSON files the aspect produced
#   3. Merges them into one combined manifest
#
# This is the "consumer" side of the aspect pattern:
#   - The aspect is the "producer" (generates per-target data)
#   - This rule is the "consumer" (aggregates and presents the data)
#
# In the real world, this consumer might be:
#   - An IDE plugin that reads the manifest to understand the project
#   - A CI step that checks the manifest for policy violations
#   - A dashboard that visualizes the dependency graph

def _target_info_manifest_impl(ctx):
    # ── Collect all JSON files from the aspect ────────────────────
    #
    # Because we declared `aspects = [target_info_aspect]` on the "deps"
    # attribute (see the rule definition below), every dep and its entire
    # transitive subgraph has already been visited by the aspect.
    #
    # We just need to grab each dep's TargetInfoAspectProvider and
    # flatten the transitive depset into a list of files.
    all_info_files = []
    for dep in ctx.attr.deps:
        if TargetInfoAspectProvider in dep:
            all_info_files.append(dep[TargetInfoAspectProvider].transitive_infos)

    # Merge all the depsets into one. This handles the case where we
    # have multiple top-level deps, each with their own subgraph.
    all_files = depset(transitive = all_info_files)

    # ── Generate the combined manifest ────────────────────────────
    #
    # We create a simple text manifest that lists all the JSON files.
    # A more sophisticated version could parse the JSONs and produce
    # a merged report, but for learning purposes this demonstrates
    # the key concept: the aspect did the per-target work, and this
    # rule just combines the results.
    manifest = ctx.actions.declare_file(ctx.label.name + "_manifest.txt")

    # We use ctx.actions.run_shell() to concatenate all the JSON files
    # into a single manifest with clear separators between entries.
    # The shell command:
    #   1. Iterates over every JSON file the aspect produced
    #   2. Prints a separator and the filename
    #   3. Prints the file contents
    #   4. Redirects everything into the output manifest
    #
    # NOTE: In production, you'd use a proper tool (Python script, Go
    # binary) instead of shell for reliability and portability. We use
    # shell here to keep the example self-contained.
    all_files_list = all_files.to_list()

    # Build the shell command. We use printf for portability.
    # Each entry gets a header line and its JSON content.
    cmd_parts = []
    for f in all_files_list:
        cmd_parts.append("echo '=== {name} ==='".format(name = f.short_path))
        cmd_parts.append("cat '{path}'".format(path = f.path))
        cmd_parts.append("echo ''")  # blank line between entries

    if cmd_parts:
        cmd = " && ".join(cmd_parts) + " > " + manifest.path
    else:
        cmd = "echo 'No targets found.' > " + manifest.path

    ctx.actions.run_shell(
        outputs = [manifest],
        inputs = all_files_list,
        command = cmd,
    )

    # Return the manifest as the rule's default output.
    return [DefaultInfo(files = depset([manifest]))]

target_info_manifest = rule(
    implementation = _target_info_manifest_impl,
    doc = """Aggregator rule that applies the target_info_aspect to its deps
    and combines all the per-target JSON files into a single manifest.

    Usage in BUILD:
        load("//tools/aspects:target_info.bzl", "target_info_manifest")

        target_info_manifest(
            name = "project_manifest",
            deps = ["//cpp-task:main", "//go-task:go_bin"],
        )

    Build it:   bazel build //tools/aspects:project_manifest
    View output: cat bazel-bin/tools/aspects/project_manifest_manifest.txt
    """,
    attrs = {
        "deps": attr.label_list(
            doc = """Targets to analyze. The target_info_aspect will automatically
            propagate through each target's entire dependency subgraph.
            You don't need to list every target — just the top-level ones.
            The aspect handles the transitive walking for you.""",
            # THIS IS THE KEY LINE — it attaches the aspect to this attribute.
            #
            # When Bazel resolves this rule's deps, it will ALSO run
            # target_info_aspect on every dep (and their deps, recursively).
            # By the time _target_info_manifest_impl runs, every dep already
            # has a TargetInfoAspectProvider attached to it.
            #
            # This is how you "connect" an aspect to a rule. Without this
            # line, the aspect would never run — it would just be a function
            # sitting in a .bzl file doing nothing.
            aspects = [target_info_aspect],
        ),
    },
)
