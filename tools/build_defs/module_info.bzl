# Exercise 4 — A rule with depset for transitive info.
#
# This is the most advanced exercise. It demonstrates depset — the
# core data structure Bazel uses for efficient transitive accumulation
# across the dependency graph.
#
# WHY DEPSETS?
# ───────────
# Imagine a dependency chain: A → B → C → D
# Each node has source files. If A wants "all transitive source files",
# using plain lists would mean:
#   D returns [d1, d2]
#   C returns [c1] + [d1, d2]           = [c1, d1, d2]
#   B returns [b1] + [c1, d1, d2]       = [b1, c1, d1, d2]
#   A returns [a1] + [b1, c1, d1, d2]   = [a1, b1, c1, d1, d2]
#
# Every level copies the entire list from below! In a large build graph
# with thousands of nodes, this explodes in memory: O(n²) total.
#
# depset solves this by storing a DAG of references:
#   D returns depset([d1, d2])
#   C returns depset([c1], transitive=[D's depset])     ← no copy!
#   B returns depset([b1], transitive=[C's depset])     ← no copy!
#   A returns depset([a1], transitive=[B's depset])     ← no copy!
#
# Each level is O(1). Only when you call .to_list() at the very end
# does it flatten into a list. Total memory: O(n).
#
# WHEN TO USE DEPSETS:
#   - Whenever you're accumulating data across transitive dependencies
#   - Source file lists, linker flags, include paths, etc.
#   - Basically any time you'd write "my stuff + all my deps' stuff"
#
# WHEN NOT TO USE DEPSETS:
#   - For small, local-only data (just use a list)
#   - When you need random access or mutation (depsets are immutable)
#
# Usage in a BUILD file:
#   load("//tools/build_defs:module_info.bzl", "module_info", "transitive_manifest")
#
#   module_info(name = "leaf", srcs = [...])
#   module_info(name = "mid", srcs = [...], deps = [":leaf"])
#   module_info(name = "top", srcs = [...], deps = [":mid"])
#   transitive_manifest(name = "manifest", deps = [":top"])

# ─── Step 1: Define the provider with a depset field ──────────────────
#
# ModuleInfo carries:
#   - name: this module's own name
#   - direct_srcs: just THIS module's source files (a plain list is fine)
#   - transitive_srcs: ALL source files from this module AND all of its
#     transitive dependencies — stored as a DEPSET for efficiency

ModuleInfo = provider(
    doc = "Carries module metadata with transitive source accumulation via depset.",
    fields = {
        "module_name": "String: the module's name.",
        "direct_srcs": "List of Files: source files directly owned by this module.",
        "transitive_srcs": "depset of Files: ALL source files from this module and all transitive deps.",
    },
)

# ─── Step 2: The producer rule — module_info ──────────────────────────
#
# Each module_info target:
#   1. Has its own source files (direct_srcs)
#   2. May depend on other module_info targets
#   3. Builds a depset that combines its own srcs with all transitive srcs

def _module_info_impl(ctx):
    # ── Collect direct source files ────────────────────────────────
    direct = ctx.files.srcs

    # ── Build the transitive depset ────────────────────────────────
    #
    # This is the key pattern. depset() takes:
    #   - direct: items owned by THIS node (a plain list)
    #   - transitive: depsets from child nodes (a list of depsets)
    #
    # The `order` parameter controls iteration order when flattened:
    #   - "default"     → unspecified (Bazel picks, usually postorder)
    #   - "postorder"   → children before parents (like linker flags)
    #   - "preorder"    → parents before children
    #   - "topological" → reverse postorder
    #
    # For source file accumulation, "default" is fine.
    #
    # IMPORTANT: We do NOT call .to_list() here! The whole point of
    # depset is to defer flattening until someone actually needs the
    # full list. Each level just adds a reference, O(1) per node.

    # Gather the transitive_srcs depsets from all dependencies.
    transitive_depsets = []
    for dep in ctx.attr.deps:
        if ModuleInfo in dep:
            transitive_depsets.append(dep[ModuleInfo].transitive_srcs)

    # Combine: my direct srcs + all transitive srcs from deps.
    all_srcs = depset(
        direct = direct,
        transitive = transitive_depsets,
    )

    # ── Return the provider ────────────────────────────────────────
    return [
        ModuleInfo(
            module_name = ctx.attr.module_name,
            direct_srcs = direct,
            transitive_srcs = all_srcs,
        ),
        # DefaultInfo with no files — this rule produces no build output.
        DefaultInfo(),
    ]

module_info = rule(
    doc = "Declares a module with source files and accumulates transitive srcs via depset. Exercise 4.",
    implementation = _module_info_impl,
    attrs = {
        "module_name": attr.string(
            doc = "Human-readable name for this module.",
            mandatory = True,
        ),
        "srcs": attr.label_list(
            doc = "Source files directly owned by this module.",
            allow_files = True,
            default = [],
        ),
        # deps can point to other module_info targets.
        # providers = [ModuleInfo] ensures only module_info targets are accepted.
        "deps": attr.label_list(
            doc = "Other module_info targets this module depends on.",
            providers = [ModuleInfo],
            default = [],
        ),
    },
)

# ─── Step 3: The consumer rule — transitive_manifest ──────────────────
#
# This rule demonstrates CONSUMING the depset. It reads ModuleInfo from
# its deps and flattens the transitive_srcs depset into a manifest file.
#
# THIS is where .to_list() gets called — at the "top" of the graph,
# when we finally need the complete flattened list.

def _transitive_manifest_impl(ctx):
    out = ctx.actions.declare_file(ctx.label.name + ".txt")

    lines = ["Transitive Module Manifest", "=" * 40, ""]

    for dep in ctx.attr.deps:
        if ModuleInfo in dep:
            info = dep[ModuleInfo]

            # ── Direct sources ─────────────────────────────────────
            # info.direct_srcs is a plain list — just this module's files.
            direct_names = [f.short_path for f in info.direct_srcs]

            # ── Transitive sources ─────────────────────────────────
            # info.transitive_srcs is a DEPSET. We call .to_list() to
            # flatten it into a plain list. This is the ONLY time we
            # should call .to_list() — at the final consumer.
            #
            # DO NOT call .to_list() in intermediate rules and pass the
            # list around — that defeats the purpose of depset and
            # brings back the O(n²) memory problem.
            all_names = [f.short_path for f in info.transitive_srcs.to_list()]

            lines.append("Module: %s" % info.module_name)
            lines.append("  Direct sources (%d):" % len(direct_names))
            for name in direct_names:
                lines.append("    - %s" % name)
            lines.append("  Transitive sources (%d total):" % len(all_names))
            for name in all_names:
                lines.append("    - %s" % name)
            lines.append("")

    ctx.actions.write(
        output = out,
        content = "\n".join(lines) + "\n",
    )

    return [DefaultInfo(files = depset([out]))]

transitive_manifest = rule(
    doc = "Flattens transitive ModuleInfo depsets into a manifest file. Exercise 4: depset consumer.",
    implementation = _transitive_manifest_impl,
    attrs = {
        "deps": attr.label_list(
            doc = "module_info targets to include in the manifest.",
            providers = [ModuleInfo],
            mandatory = True,
        ),
    },
)
