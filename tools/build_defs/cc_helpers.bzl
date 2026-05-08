# C++ build helpers — shared across the monorepo.
#
# Usage from any BUILD file:
#   load("//tools/build_defs:cc_helpers.bzl", "target_name_from_path", "cc_lib_attrs")
#
# Starlark constraints demonstrated:
#   - No mutable global state (module-level values freeze after load)
#   - No while loops, no recursion (loops are bounded via for)
#   - No I/O, no exceptions, no classes
#   - fail() instead of raise
#   - Strings are byte strings

# --- Derive a target name from a file path ---
# e.g. "src/utils/parser.cc" -> "parser_lib"
def target_name_from_path(path, suffix = "_lib"):
    """Compute a target name from a source file path."""
    if not path:
        fail("target_name_from_path: path must not be empty")

    # Strip directory prefix — find last "/"
    basename = path
    for i in range(len(path)):
        if path[i] == "/":
            basename = path[i + 1:]

    # Strip file extension — find last "."
    name = basename
    for i in range(len(basename)):
        if basename[i] == ".":
            name = basename[:i]

    return name + suffix

# --- Return cc_library attribute dict from minimal inputs ---
def cc_lib_attrs(name, srcs, hdrs = None, deps = None):
    """Return a dict of cc_library attributes from minimal inputs."""
    if not srcs:
        fail("cc_lib_attrs: srcs must not be empty for target '%s'" % name)

    attrs = {
        "name": name,
        "srcs": srcs,
        "visibility": ["//visibility:public"],
    }
    if hdrs:
        attrs["hdrs"] = hdrs
    if deps:
        attrs["deps"] = deps

    print("cc_lib_attrs: configured target '%s' with %d srcs" % (name, len(srcs)))

    return attrs

# --- Batch target names ---
def batch_target_names(paths, suffix = "_lib"):
    """Derive target names for a list of source file paths."""
    names = []
    for p in paths:
        names.append(target_name_from_path(p, suffix))
    return names

# --- Source file filtering ---
# This list is module-level. After this .bzl finishes loading,
# it becomes frozen. Any file that load()s it cannot append to it.
SUPPORTED_EXTENSIONS = [".cc", ".c", ".cpp", ".h", ".hpp"]

def is_supported_source(path):
    """Check if a file has a supported C/C++ extension."""
    for ext in SUPPORTED_EXTENSIONS:
        if path.endswith(ext):
            return True
    return False

def filter_sources(files):
    """Filter a list of file paths to only supported C/C++ sources."""
    result = []
    for f in files:
        if is_supported_source(f):
            result.append(f)
        else:
            print("filter_sources: skipping unsupported file '%s'" % f)
    return result
