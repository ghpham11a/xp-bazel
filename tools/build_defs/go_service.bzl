"""Symbolic macro: go_service bundles a go_library, go_binary, and go_test."""

load("@rules_go//go:def.bzl", "go_binary", "go_library", "go_test")

def _go_service_impl(name, srcs, test_srcs, deps = [], visibility = None):
    lib_name = name + "_lib"

    go_library(
        name = lib_name,
        srcs = srcs,
        importpath = "xp_bazel/" + name,
        deps = deps,
        visibility = visibility,
    )

    go_binary(
        name = name + "_bin",
        embed = [":" + lib_name],
        visibility = visibility,
    )

    go_test(
        name = name + "_test",
        srcs = test_srcs,
        embed = [":" + lib_name],
    )

go_service = macro(
    doc = "Creates a Go library, binary, and test from a single call.",
    implementation = _go_service_impl,
    attrs = {
        "srcs": attr.label_list(allow_files = [".go"]),
        "test_srcs": attr.label_list(allow_files = [".go"]),
        "deps": attr.label_list(default = []),
    },
)
