# Common build helpers — language-agnostic validation utilities.
#
# Usage from any BUILD file:
#   load("//tools/build_defs:common.bzl", "require_non_empty")
#
# Starlark constraints demonstrated:
#   - fail() halts immediately, no try/catch
#   - No while, no recursion, no classes, no I/O
#   - Frozen globals

def require_non_empty(name, items):
    """Halts the build if items is empty. No try/catch — fail() is final."""
    if not items:
        fail("'%s' must not be empty — the build cannot continue" % name)
    return items

# --- Constraint demos (uncomment to see errors) ---

# 1. No while loops:
# while True:       # ERROR: 'while' not allowed in Starlark
#     pass

# 2. No recursion (Starlark detects and rejects it):
# def factorial(n):
#     if n <= 1: return 1
#     return n * factorial(n - 1)  # ERROR: function called recursively

# 3. No classes:
# class Foo:        # ERROR: 'class' not allowed
#     pass

# 4. No exceptions:
# try:              # ERROR: 'try' not allowed
#     x = 1
# except:
#     pass

# 5. No I/O:
# open("file.txt")  # ERROR: name 'open' is not defined

# 6. Frozen globals — this list is frozen after load:
FROZEN_LIST = ["a", "b", "c"]
# Any .bzl file that load()s FROZEN_LIST cannot do:
#   FROZEN_LIST.append("d")  # ERROR: trying to mutate a frozen list
# Workaround: make a copy first:
#   my_copy = list(FROZEN_LIST)
#   my_copy.append("d")  # works fine
