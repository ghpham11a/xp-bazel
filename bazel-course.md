# Bazel: From Beginner to Expert

A self-paced course for engineers who haven't worked deeply with build systems before. The endpoint is comfort writing custom rules, debugging hermeticity issues, and running a Bazel monorepo at scale.

> **A note on Bazel versions.** This course targets **Bazel 9 (released January 2026) and later**. Bazel 9 removed the legacy `WORKSPACE` file system entirely — `MODULE.bazel` (Bzlmod) is now the only way to manage external dependencies. A lot of older tutorials and Stack Overflow answers reference `WORKSPACE`, `http_archive` at the top level, `rules_*_dependencies()` macros, and so on. Treat those as historical. If you're reading something that puts dependencies in `WORKSPACE`, it's pre-Bazel-8 material.

---

## How to use this course

Each module has four parts:

1. **Concepts** — what you need to understand before touching a keyboard.
2. **Hands-on** — a small project or exercise. Type it out, don't copy-paste. Bazel's error messages are how you actually learn it.
3. **Pitfalls** — the specific things that confuse newcomers, written down so you recognize them when they bite.
4. **Resources** — primary sources to go deeper.

Time estimates assume an experienced developer working part-time. Total course is roughly **60–100 hours of focused work**, spread however you like. Don't rush — Bazel's mental model is the whole game, and skimming makes the advanced modules incoherent.

There's a **capstone project** at the end. If you can finish it, you're past "intermediate" by any reasonable definition.

---

# Phase 1 — Foundations

The goal of Phase 1 is to stop being confused. By the end you should be able to read a small Bazel project and predict what `bazel build //...` will do.

## Module 1 — What Bazel Is, and Why It Exists

**Time:** 2–3 hours of reading.

### Concepts

Before Bazel, you need to understand what a build system actually does. A build system takes source files plus a description of how they relate, and produces artifacts (binaries, libraries, container images, test reports). The interesting questions are:

- *What needs to be rebuilt when something changes?* (Incrementality.)
- *Can two people on different machines get bit-for-bit identical outputs?* (Reproducibility / hermeticity.)
- *Can the build be parallelized across cores or machines?* (Scalability.)
- *How do I express dependencies between languages, generators, and tools?* (Expressiveness.)

Tools like `make`, `cmake`, `gradle`, `npm scripts`, and shell scripts each answer some of these but generally fail at scale because they trust the filesystem and the user's environment too much.

Bazel's central bet is: **if you describe your build as a graph of pure, declarative actions whose inputs and outputs are fully enumerated, then everything else (caching, parallelism, remote execution, reproducibility) falls out for free.** The price you pay is that you have to actually enumerate everything. No "just run this script and see what it produces."

Key vocabulary to seed in your head — these get fleshed out across the course:

- **Workspace** — the root of a Bazel project. Identified by a `MODULE.bazel` file.
- **Package** — any directory containing a `BUILD` (or `BUILD.bazel`) file. Packages are the unit of build organization.
- **Target** — a single buildable thing inside a package: a library, a binary, a test, a generated file. Declared by calling a *rule* in a `BUILD` file.
- **Rule** — a function (like `cc_binary`, `py_library`, or one you write yourself) that takes attributes and produces targets.
- **Label** — the unique name of a target, like `//path/to/package:target_name`.
- **Action** — an actual command Bazel runs (a compiler invocation, a file copy). Rules expand into actions at analysis time.
- **Starlark** — the Python-like language all `BUILD` and `.bzl` files are written in.

Don't memorize. Just recognize them when they show up.

### Hands-on

No coding yet. Read these, in order:

1. The "Why Bazel?" page on the official site.
2. The first 20 minutes of any "Intro to Bazel" conference talk on YouTube. ("BazelCon" recordings are good.)
3. Skim the table of contents of the official Bazel docs. You don't need to read it — just see what's there. You'll come back.

### Pitfalls

The single biggest mental adjustment from `make`/`gradle`/`npm` is: **Bazel does not let you reach outside the declared inputs.** If your test reads `/etc/hosts` or hits the network, Bazel considers that a bug. This feels restrictive at first; it's the entire point.

### Resources

- Official site: <https://bazel.build>
- "Build Systems à la Carte" (Mokhov, Mitchell, Peyton Jones) — academic but the clearest comparison of `make`, `shake`, `bazel`, etc. ever written.

---

## Module 2 — Installation and Your First Build

**Time:** 2 hours.

### Concepts

You will install Bazel via **Bazelisk**, not directly. Bazelisk is a tiny wrapper that reads a `.bazelversion` file in your project and downloads the matching Bazel. This is the only way to install Bazel that doesn't cause version-pinning headaches later.

### Hands-on

Install Bazelisk. On macOS: `brew install bazelisk`. On Linux: download the binary from the bazelbuild/bazelisk GitHub releases and put it in your PATH as `bazel`. On Windows: use scoop or download directly.

Now build the canonical hello-world. Create a directory, then:

```
mkdir hello-bazel && cd hello-bazel
echo "9.0.0" > .bazelversion
```

Create `MODULE.bazel`:

```python
module(name = "hello_bazel", version = "0.1.0")

bazel_dep(name = "rules_python", version = "0.40.0")
```

(Check the latest version of `rules_python` on the Bazel Central Registry at registry.bazel.build before pasting — versions move.)

Create `hello/BUILD.bazel`:

```python
load("@rules_python//python:py_binary.bzl", "py_binary")

py_binary(
    name = "hello",
    srcs = ["hello.py"],
)
```

Create `hello/hello.py`:

```python
print("Hello, Bazel!")
```

Now run:

```
bazel run //hello:hello
```

Observe what happens. The first run will be slow — Bazel is downloading Python rules, setting up a sandboxed Python toolchain, and analyzing the build graph. Run it again and notice it's instant: that's the cache.

Then try:

```
bazel build //hello:hello
bazel query //hello:all
bazel query 'deps(//hello:hello)'
bazel clean
```

Read the output of each. `query` is your friend.

### Pitfalls

- If you put dependencies in `WORKSPACE`, they will be ignored on Bazel 9+. The file is dead.
- `BUILD` and `BUILD.bazel` are equivalent. Pick one and be consistent — most projects use `BUILD.bazel` because some editors syntax-highlight it better.
- Bazel doesn't read your shell's `PATH` at build time for compilers (in well-configured projects). If your build "works on my machine but not in CI," your build is leaking — Module 14 covers this.

### Resources

- Bazelisk: <https://github.com/bazelbuild/bazelisk>
- Bazel Central Registry: <https://registry.bazel.build>

---

## Module 3 — The Core Mental Model

**Time:** 4–6 hours. **Do not skip this module.** Almost every "Bazel is confusing" complaint is really "I didn't internalize Module 3."

### Concepts

**The graph.** A Bazel build is a directed acyclic graph. Nodes are targets and actions; edges are dependencies. When you ask Bazel to build something, it walks the graph backwards from your target, figures out what's already cached, runs the missing actions in parallel, and produces your output.

**Phases.** Every Bazel invocation goes through three phases, and many error messages reference them:

1. **Loading** — read `MODULE.bazel` and all transitively referenced `BUILD` files. Evaluate Starlark. Output: an unresolved target graph.
2. **Analysis** — for each target, call its rule's implementation function to produce concrete actions. Output: an action graph.
3. **Execution** — actually run the actions, in parallel where possible.

When something goes wrong, the phase tells you what kind of fix you need. Loading errors are syntactic / Starlark issues. Analysis errors are about how rules are wired together. Execution errors are about actual commands failing.

**Labels.** A label uniquely identifies a target. Full form: `@repo//package/path:target_name`.

- `@repo` — the external repository. Omit for the current workspace.
- `//package/path` — the package, relative to workspace root. The path is the directory containing the `BUILD.bazel`.
- `:target_name` — the target. If omitted, defaults to the last path component (so `//foo/bar` means `//foo/bar:bar`).

Special label syntax to know:

- `:foo` — relative label inside the same package.
- `//...` — every target in the workspace.
- `//foo/...` — every target under `//foo`.
- `//foo:all` — every target inside the package `//foo`.

**Visibility.** Every target has a visibility attribute that says *which other packages may depend on it*. Default is `private` (only the same package). You'll constantly hit `target X is not visible from Y` errors at first. Set `visibility = ["//visibility:public"]` for libraries others can depend on, or use a more specific list like `["//foo:__pkg__", "//bar:__subpackages__"]`.

**Hermeticity.** A build action is hermetic if its outputs depend only on its declared inputs. Bazel sandboxes actions on Linux/macOS to enforce this — actions run in a temp directory containing only their declared inputs. This is why everything Just Works once you get it right, and why everything Just Breaks when you don't declare an input.

### Hands-on

Extend the hello-world from Module 2. Add a library and have the binary depend on it.

`hello/lib/BUILD.bazel`:

```python
load("@rules_python//python:py_library.bzl", "py_library")

py_library(
    name = "greeter",
    srcs = ["greeter.py"],
    visibility = ["//hello:__pkg__"],
)
```

`hello/lib/greeter.py`:

```python
def greet(name):
    return f"Hello, {name}!"
```

Update `hello/hello.py`:

```python
from hello.lib.greeter import greet
print(greet("Bazel"))
```

Update `hello/BUILD.bazel`:

```python
load("@rules_python//python:py_binary.bzl", "py_binary")

py_binary(
    name = "hello",
    srcs = ["hello.py"],
    deps = ["//hello/lib:greeter"],
)
```

Now do these things and watch carefully:

1. `bazel run //hello:hello` — confirm it works.
2. Change `visibility` on `greeter` to `["//visibility:private"]`. Try to build. Read the error.
3. Restore visibility. Now run `bazel query 'deps(//hello:hello)' --output=graph` and look at the graph.
4. Run `bazel build //hello:hello --subcommands`. This shows you every actual command Bazel ran. Read it. This is the "execution phase made visible."
5. Touch `greeter.py` (just save it without changes) and rebuild. Notice nothing rebuilds, because Bazel hashes content, not mtime.
6. Actually edit `greeter.py` and rebuild. Watch what gets re-run and what doesn't.

### Pitfalls

- **Visibility errors are not bugs.** They're Bazel telling you the dependency you wrote isn't allowed. Either fix the visibility or rethink the dependency.
- **`load()` statements are required.** Unlike Python, Starlark has no implicit imports. Every rule used in a `BUILD` file must be `load`ed first. The file path inside the `load` is a label.
- **Don't read files at load time.** If you find yourself wanting to do `open("config.txt")` in a `BUILD` file, you're misusing Bazel. The fix is usually a genrule or a custom rule (Module 10).

### Resources

- "Concepts and Terminology": <https://bazel.build/concepts/build-ref>
- "Visibility": <https://bazel.build/concepts/visibility>

---

# Phase 2 — Real Projects

By the end of Phase 2 you can stand up a Bazel build for a non-trivial multi-language project, manage its external dependencies, run its tests, and configure it for different environments.

## Module 4 — Building Multi-Language Projects

**Time:** 6–10 hours.

### Concepts

Bazel doesn't have built-in knowledge of any language anymore (since Bazel 8 + 9). Everything goes through rulesets distributed via the BCR. The big ones:

- **rules_cc** — C and C++.
- **rules_java** — Java.
- **rules_python** — Python.
- **rules_go** — Go.
- **rules_rust** — Rust.
- **rules_js** / **aspect_rules_ts** — JavaScript/TypeScript (the Aspect-maintained ones are the modern choice; the legacy `rules_nodejs` is deprecated).
- **rules_kotlin** — Kotlin.
- **rules_swift** — Swift / Apple platforms.

Each ruleset gives you the same rough vocabulary:

- `<lang>_library` — a library target, used as a dep by other targets.
- `<lang>_binary` — an executable.
- `<lang>_test` — a test runnable via `bazel test`.

The interesting parts are language-specific. Java has resource handling and javac options. Python has `imports` and `main`. C++ has `copts`, `linkopts`, and headers vs. sources. You learn each one as needed.

### Hands-on

Pick **one** language you know well and one you don't. Build a project in each. Suggested combinations:

- If you know Python: do Python + Go.
- If you know Java: do Java + C++.
- If you know JavaScript: do TypeScript + Python.

For each project, build:

1. A library.
2. A binary depending on the library.
3. Two libraries that depend on each other (verify Bazel catches the cycle).
4. A binary that depends on libraries from *both* languages, glued together somehow (e.g., a shell script or a Python binary that exec's a Go binary).

For the cross-language part, look up `data` attribute and `genrule` — these are the bridges.

### Pitfalls

- **Headers in C++** are particularly annoying. `cc_library` distinguishes between `srcs`, `hdrs`, `textual_hdrs`, and `private_hdrs`, and visibility rules differ for each. Read the rules_cc docs carefully.
- **Python imports.** Bazel's Python support uses an `imports = [".."]` attribute to control sys.path. If your imports work outside Bazel but not inside, this is usually why.
- **Go's GOPATH model is gone in Bazel.** rules_go uses module-style imports. The `gazelle` tool generates BUILD files from your Go source — most Go-on-Bazel projects use it.
- **TypeScript is the hardest of the popular languages on Bazel.** If you're new to Bazel, do not pick TS as your first language. Get comfortable elsewhere first.

### Resources

- Each ruleset has its own README on GitHub. Read it.
- "Awesome Bazel" list: <https://github.com/jin/awesome-bazel>

---

## Module 5 — External Dependencies with Bzlmod

**Time:** 4–6 hours.

### Concepts

A **Bazel module** is a versioned project published in a registry. The default registry is the Bazel Central Registry (BCR) at registry.bazel.build. Your `MODULE.bazel` file lists what modules you depend on.

```python
module(name = "my_project", version = "1.0.0")

bazel_dep(name = "rules_python", version = "0.40.0")
bazel_dep(name = "rules_go", version = "0.50.0")
bazel_dep(name = "googletest", version = "1.14.0", repo_name = "com_google_googletest")
```

Three things to understand:

**Minimal Version Selection (MVS).** Borrowed from Go modules. If your dep tree includes module A 1.2 and module A 1.5, Bazel picks 1.5. Period. There's no SAT solver, no version ranges. This makes resolution fast and deterministic.

**Module extensions.** Some dependencies aren't Bazel modules — they're Maven artifacts, pip packages, npm packages, git repos, raw archives. Module extensions are the bridge. You use them like this:

```python
pip = use_extension("@rules_python//python/extensions:pip.bzl", "pip")
pip.parse(
    hub_name = "my_pip_deps",
    python_version = "3.12",
    requirements_lock = "//:requirements_lock.txt",
)
use_repo(pip, "my_pip_deps")
```

This calls into rules_python's pip extension to read your requirements file and create repos for each package.

**The lockfile.** `MODULE.bazel.lock` is generated automatically and pins exact versions and hashes of everything. Commit it. Without it, builds aren't reproducible.

### Hands-on

Take one of your projects from Module 4 and add three real external dependencies:

1. A pure Bazel module (e.g., `bazel_skylib`).
2. A language ecosystem package (a pip package, a Maven artifact, an npm package).
3. A C/C++ library from the BCR (e.g., `abseil-cpp` or `googletest`).

Then:

- `bazel mod graph` — see your full dep graph.
- `bazel mod show_repo @<repo_name>` — inspect a specific repo.
- `bazel mod explain @<repo_name>` — find out why something is in your build.

Deliberately introduce a version conflict (depend on two modules that both want different versions of a third). Watch how MVS resolves it. Then read about `single_version_override` and `multiple_version_override` in the docs and try them.

### Pitfalls

- **`use_repo` is mandatory.** Modules and extensions don't make their repos visible automatically. If you `bazel_dep` something but forget `use_repo`, you can't reference it. The error messages here are improving but still confusing.
- **Maven dependencies use `rules_jvm_external`'s `maven` extension.** Don't try to write Maven coords directly into `bazel_dep`.
- **Don't pin module versions in BUILD files.** Module versions live in `MODULE.bazel`. BUILD files just say `@bazel_skylib//...`, with no version, because there's only ever one resolved version per build.

### Resources

- Bzlmod docs: <https://bazel.build/external/module>
- Migration guide (useful even if not migrating, because it explains *why* Bzlmod): <https://bazel.build/external/migration>

---

## Module 6 — Testing

**Time:** 3–4 hours.

### Concepts

Tests in Bazel are just targets declared with a `*_test` rule. `bazel test //...` runs everything. Two ideas to absorb:

**Test sizes.** Each test target has a `size` attribute: `small`, `medium`, `large`, `enormous`. This isn't just a label — Bazel uses it to set timeouts and infer parallelism. Mark integration tests `large`, unit tests `small`. CI can filter: `bazel test //... --test_size_filters=small`.

**Test flakiness.** Bazel can detect flakes (`--runs_per_test=10`), retry flakes (`--flaky_test_attempts=3`), and mark targets `flaky = True`. Use sparingly — flaky tests are bugs.

**Caching.** Test results are cached too. If nothing in a test's transitive deps changed, Bazel doesn't re-run it. This is one of Bazel's killer features and one of the most surprising the first time you see it. To force re-run: `--cache_test_results=no`.

### Hands-on

For your Module 4 project, write:

1. A unit test for each library.
2. A test that uses test data (a fixture file). Use the `data` attribute. Use the `runfiles` library (rules_python provides one; rules_go provides one) to find the file at runtime. **Do not** use absolute paths or assume CWD.
3. Run `bazel test //...`. Then run it again. Notice the cache.
4. Make one test deliberately flaky. Mark it `flaky = True`. Run with `--flaky_test_attempts=5`.
5. Run `bazel coverage //...`. (Setup varies by language; check the ruleset docs.)

### Pitfalls

- **CWD inside a test is not what you think it is.** Bazel runs tests in a sandboxed runfiles tree. Always use the runfiles library to find data files.
- **Tests that hit the network will pass locally and fail in remote execution.** This is hermeticity biting you. Mock the network or mark the test as needing network: `tags = ["requires-network"]`. (Some setups disallow this entirely.)
- **`bazel test //...` will skip non-test targets gracefully**, but `bazel test //some/specific:library` errors. Use `:all` carefully.

### Resources

- "Writing Tests": <https://bazel.build/reference/test-encyclopedia>

---

## Module 7 — Configuration: bazelrc, Build Flags, Platforms

**Time:** 3–4 hours.

### Concepts

**bazelrc files.** Bazel reads configuration from `.bazelrc` files. Yours lives at the workspace root and is committed. There's also a `~/.bazelrc` for user-specific settings. Format:

```
build --jobs=auto
build --keep_going
test --test_output=errors

build:ci --remote_cache=https://cache.example.com
build:ci --remote_upload_local_results

build:debug -c dbg
build:debug --strip=never
```

The colon syntax (`:ci`, `:debug`) defines named *configs*. Activate with `--config=ci`. This is how you have one `bazelrc` that handles local dev, CI, and release builds.

**Compilation modes.** Bazel has three: `fastbuild` (default, no opts, fast compile), `dbg` (debug symbols), `opt` (release). Set with `-c opt` or `--compilation_mode=opt`.

**Platforms and constraints.** Modern Bazel uses *platforms* to describe target environments. A platform is a set of constraint values (cpu = arm64, os = linux, libc = glibc). Toolchains advertise which platforms they support. When you build, Bazel resolves the right toolchain for the target platform. For most language rulesets, this is automatic. You'll only think about it when cross-compiling (Module 14).

### Hands-on

For your Module 4 project, create a `.bazelrc` with:

- A default config that enables BES (build event service) output to a local file.
- A `:ci` config tuned for CI (more strict, no cache writes).
- A `:debug` config for debug builds.
- A `:asan` config for AddressSanitizer (look up the flags).

Then run with each: `bazel build //... --config=debug`, `--config=ci`, etc. Inspect the BES output file — that's what tools like Buildbarn and BuildBuddy consume.

### Pitfalls

- **Order matters in bazelrc.** Later flags override earlier. Configs are flattened.
- **Don't use `--define`.** It's the old way of passing build-time flags and has subtle correctness issues with caching. Use Starlark `config_setting` and user-defined build flags instead.
- **`startup` flags vs. `build` flags.** Startup flags configure the Bazel server itself and require a server restart to change. `bazel shutdown` after editing them.

### Resources

- "User's manual": <https://bazel.build/reference/command-line-reference>
- "bazelrc": <https://bazel.build/run/bazelrc>

---

# Phase 3 — Extending Bazel

This is where Bazel goes from "interesting" to "powerful." The price of admission is learning Starlark properly.

## Module 8 — Starlark, the Configuration Language

**Time:** 4–6 hours.

### Concepts

Starlark looks exactly like Python — same syntax, same indentation, same `def`/`if`/`for`. But it's deliberately not Python. Differences that matter:

- **No mutable global state.** Module-level variables are frozen after the file loads.
- **No `while`, no recursion.** Loops are bounded; functions can't call themselves. This guarantees evaluation terminates.
- **No I/O, no exceptions, no classes.** You have functions, lists, dicts, structs, and a small set of builtins.
- **`fail()` instead of `raise`.** Errors halt evaluation immediately.
- **Strings are byte strings.** No unicode surprises.

These constraints exist so Bazel can analyze, parallelize, and cache Starlark evaluation. Treat them as features.

Three file types use Starlark:

1. **`MODULE.bazel`** — module declarations. Limited to a small DSL.
2. **`BUILD.bazel`** — package definitions. Calls rules; can define macros inline (don't).
3. **`.bzl` files** — your custom rules, macros, providers, helpers. Loaded via `load()`.

### Hands-on

Write a `.bzl` file that defines a few helper functions. Make it useful — for example, a helper that takes a list of source file globs and returns a `cc_library` target, or a function that computes a target name from a file path.

Then experiment with `print()`, `fail()`, and `bazel info` to verify your understanding.

Read 200 lines of `bazel_skylib`'s source code (<https://github.com/bazelbuild/bazel-skylib>). It's the standard library. Notice how they write Starlark.

### Pitfalls

- **Don't try to make Starlark do Python things.** Want HTTP? Read environment variables? Time-of-day? You can't, by design.
- **`load()` paths are labels, not relative paths.** `load("//tools:my_helpers.bzl", "my_helper")`, not `load("../tools/my_helpers.bzl", ...)`.
- **Frozen values can confuse you.** A list returned from one `.bzl` file is frozen — you can't append to it in another file. Make a copy first.

### Resources

- Starlark spec: <https://github.com/bazelbuild/starlark>
- Bazel-flavored Starlark docs: <https://bazel.build/rules/language>

---

## Module 9 — Macros

**Time:** 2–3 hours.

### Concepts

A **macro** is a Starlark function that, when called from a `BUILD` file, expands into one or more rule calls. Macros are how you reduce boilerplate. Example: every microservice in your monorepo needs a binary, a Docker image, and a deployment target. Write one macro that creates all three from a few inputs.

There are two flavors:

- **Legacy macros** — just regular Starlark functions. Bazel sees the expanded targets but not the macro itself. Errors point at the expansion, which can be confusing.
- **Symbolic macros** — newer (Bazel 8+). First-class concept. Bazel knows about the macro itself, gives better error messages, allows lazy evaluation. Use these for new code.

### Hands-on

Write a symbolic macro for your project that:

- Takes a name and a list of srcs.
- Creates a library, a test that exercises that library, and a wrapper binary, all in one call.

Use it in a `BUILD.bazel` and expand it with `bazel query --output=build //your:target` to see what it produced.

### Pitfalls

- **Don't put complex logic in macros.** If you find yourself computing things, generating files, or making structural decisions, you want a custom rule (Module 10), not a macro.
- **Macros run at loading time.** They have no access to providers, action outputs, or anything from analysis or execution.

### Resources

- "Macros": <https://bazel.build/extending/macros>

---

## Module 10 — Custom Rules and Providers

**Time:** 8–12 hours. This is the big one.

### Concepts

A **rule** is a function that, given attributes (srcs, deps, etc.), produces a set of *actions* and returns a set of *providers*.

- **Action** — a hermetic command Bazel will run during execution. You declare it with `ctx.actions.run()`, `ctx.actions.run_shell()`, `ctx.actions.write()`, `ctx.actions.symlink()`, etc.
- **Provider** — a typed bag of data that one rule passes to dependents. Like return values from one node to its consumers in the build graph. `DefaultInfo` is built in (carries runfiles and default outputs). You define your own with `provider()`.

A rule's implementation function:

```python
def _my_rule_impl(ctx):
    out = ctx.actions.declare_file(ctx.label.name + ".txt")
    ctx.actions.run_shell(
        outputs = [out],
        inputs = ctx.files.srcs,
        command = "cat $@ > {output}".format(output = out.path),
        arguments = [f.path for f in ctx.files.srcs],
    )
    return [DefaultInfo(files = depset([out]))]

my_rule = rule(
    implementation = _my_rule_impl,
    attrs = {
        "srcs": attr.label_list(allow_files = True),
    },
)
```

Read that until it's obvious. The whole rule system is variations on this pattern.

**`depset`** is critical. It's a memory-efficient set built for transitive accumulation across the dep graph. When a rule wants to expose "all my transitive dependencies' outputs," it returns a depset. Don't use lists for this — they explode in memory on large graphs.

### Hands-on

Build, in order:

1. **A trivial rule** that copies a file with a header prepended. Inputs: a file. Outputs: the same file with a header line.
2. **A rule that runs a tool.** Wrap a real CLI (e.g., `protoc` or `markdownlint` or your own script). Use `ctx.actions.run` with `executable = ctx.executable.tool` and an `attr.label(executable = True, cfg = "exec")` attribute.
3. **A rule with a custom provider.** Define a provider, return it from the rule, write a second rule that consumes it.
4. **A rule with `depset` for transitive info.** Make a rule whose provider accumulates info from all transitive deps.

You'll spend most of your time here reading other rulesets' source code. `rules_cc` is too complex to start with. `bazel_skylib`'s rules and `rules_python`'s simpler rules are better references.

### Pitfalls

- **`cfg = "exec"` vs `cfg = "target"`.** Tools that *run during the build* (a code generator, a compiler) are exec-cfg. Things that *end up in the output* are target-cfg. Confusing this causes "wrong architecture" errors when cross-compiling.
- **Writing files with `ctx.actions.write` is fine for small content.** For anything based on inputs, you must use `run` or `run_shell`, not `write`.
- **Action correctness.** Every file your action reads must be in `inputs`. Every file it writes must be in `outputs`. If you cheat, sandboxing will catch you locally; if it doesn't, remote execution will.

### Resources

- "Rules": <https://bazel.build/extending/rules>
- "Reading rules_*": pick a small ruleset on GitHub and read all of it.
- The book: *Software Engineering at Google*, Chapter 18 ("Build Systems and Build Philosophy"). Best high-level explanation of the design.

---

## Module 11 — Aspects

**Time:** 4–6 hours.

### Concepts

An **aspect** is "a rule that walks the dep graph of an existing target." Aspects let you add behavior to targets without modifying their rule definitions. Classic uses:

- A linter that walks every C++ target and runs clang-tidy.
- An IDE-info generator that walks every Java target and emits an IDE-readable manifest.
- A dependency-graph extractor for security scanning.

Aspects propagate along specific attribute edges (you say "follow `deps`") and produce their own providers. The original targets are untouched.

### Hands-on

Write an aspect that walks a project and produces, for each `cc_library` (or whichever language), a JSON file describing the target. Then write a rule that consumes the aspect's output and produces a single combined manifest.

This is the canonical aspect tutorial — every IDE plugin for Bazel is some flavor of this.

### Pitfalls

- **Aspects run for every transitive target.** If your aspect is slow, your whole build is slow.
- **Aspect-over-aspect composition is gnarly.** Avoid until you really need it.

### Resources

- "Aspects": <https://bazel.build/extending/aspects>

---

# Phase 4 — Scale and Mastery

Phase 4 is what you reach for when your project is big enough that "it builds" isn't enough — you need it to build *fast*, *reproducibly*, and *across machines*.

## Module 12 — Build Performance: Caching, Sandboxing, Workers

**Time:** 4–6 hours.

### Concepts

**Local caching.** Bazel caches action outputs in `~/.cache/bazel`. Re-running a build that produced output X with input hash H just reads from cache. This is on by default.

**Sandboxing.** On Linux and macOS, every action runs in a sandbox — a fresh, minimal filesystem with only declared inputs visible. This enforces hermeticity. It costs a few percent in performance but pays back massively in correctness.

**Persistent workers.** Compilers like javac and the TypeScript compiler are slow to start. A persistent worker is a long-running process Bazel keeps alive between actions. The compiler stays warm, JIT stays hot, builds get faster. Most major language rulesets enable workers by default.

**Profiling.** `bazel build //... --profile=profile.gz` produces a Chrome-tracing profile. Open it in `chrome://tracing` or `ui.perfetto.dev` to see exactly where time goes. The first time you do this on a real project is illuminating.

### Hands-on

On your real project (or a clone of an OSS one):

1. Run a clean build, with `--profile`. Look at the profile.
2. Run an incremental build (touch one source file). Profile that. Note the difference.
3. Disable workers (`--noworker_sandboxing` and look up `--strategy=...=local` flags). Re-time.
4. Disable sandboxing (`--spawn_strategy=local`). Re-time. Now run a test that has hidden deps it shouldn't have. Notice it might pass when it should fail. Re-enable sandboxing.

### Pitfalls

- **Cache poisoning is real.** If a non-hermetic action sneaks in (reads `/etc/hosts`, embeds a timestamp, etc.), it pollutes your cache. The fix is always to make the action hermetic, not to disable the cache.
- **Don't disable sandboxing for performance.** It's almost never the bottleneck.

### Resources

- "Performance guide": <https://bazel.build/configure/best-practices>
- "Profiling": <https://bazel.build/rules/performance>

---

## Module 13 — Remote Execution and Caching

**Time:** 6–10 hours.

### Concepts

**Remote caching** — a shared cache server. Your team's CI fills it; developers' machines read from it. A cold build on a new machine can complete in seconds because everything's already cached. The protocol is "Remote Execution API" (REAPI), implemented by Bazel and a handful of cache servers.

**Remote execution** — actions run on a remote cluster, not your laptop. You ship inputs, the cluster runs them, you get outputs back. With sufficient parallelism, builds that take 30 minutes locally finish in 2 minutes.

The two cache implementations to know:

- **bazel-remote** — simple HTTP/gRPC cache. Easy to self-host.
- **BuildBuddy / EngFlow / Buildbarn** — full RBE (remote build execution) systems. Hosted or self-hosted.

The flags:

```
build --remote_cache=grpc://cache.example.com
build --remote_executor=grpc://exec.example.com  # only for full RBE
build --remote_upload_local_results              # write back to cache
build --remote_download_minimal                  # don't ship outputs back unless asked
```

### Hands-on

1. Run a local `bazel-remote` instance (it's a single Go binary). Point your project at it. Build twice. Notice the second build is faster across `bazel clean`.
2. Sign up for the BuildBuddy free tier or set up a self-hosted equivalent. Do the same.
3. Read the REAPI protobuf: <https://github.com/bazelbuild/remote-apis>. You don't need to memorize it, but seeing the schema demystifies a lot.
4. Optional: try full remote execution. Most hosted RBE providers have free tiers.

### Pitfalls

- **Cache misses are usually a hermeticity bug.** If your CI consistently misses the cache that developers fill (or vice versa), something differs in the action input — usually a path, a timestamp, or an environment variable.
- **`--remote_download_minimal` saves bandwidth but breaks `bazel run` for remote-only artifacts.** Switch to `--remote_download_toplevel` or accept the trade-off.

### Resources

- REAPI: <https://github.com/bazelbuild/remote-apis>
- bazel-remote: <https://github.com/buchgr/bazel-remote>

---

## Module 14 — Hermeticity, Toolchains, and Cross-Compilation

**Time:** 6–8 hours.

### Concepts

**Hermetic toolchains** mean your compiler (clang, gcc, javac, rustc) is a *Bazel-tracked input*, not whatever the system has installed. This is the difference between "works on my machine" and "produces bit-identical outputs on every machine forever."

For C/C++, the gold standard is hermetic clang via toolchains_llvm. For Python, rules_python's hermetic interpreter. For Java, rules_java's downloaded JDK. For Go, rules_go ships its own.

**Toolchain resolution.** When a target needs a compiler, Bazel asks: "what's my target platform?" and then asks each registered toolchain "do you support this platform?" The first match wins. Cross-compiling is just "set a different `--platforms=` and the right toolchain gets selected."

**Platform constraints.** Defined as `constraint_setting` (the dimension, like CPU) and `constraint_value` (a specific value, like `arm64`). The `@platforms` module ships standard ones. You can define your own (e.g., `embedded` vs. `server`).

### Hands-on

1. Configure a hermetic C++ toolchain for your project using `toolchains_llvm` or similar. Verify by running `bazel build` on a fresh container with no clang installed.
2. Build a `cc_binary` for Linux x86_64, then for Linux ARM64, from the same machine. Use `--platforms=`.
3. Define a custom `constraint_setting` and `constraint_value`. Use `select()` in a target's deps to switch behavior based on platform.

### Pitfalls

- **The system toolchain trap.** If you don't configure a hermetic toolchain, Bazel falls back to whatever's on PATH. Builds will silently differ across machines. Always check.
- **`select()` is your friend.** Conditional compilation in Bazel is `select({"//config:debug": [...], "//config:release": [...]})`, not `if`/`else` in Starlark.
- **Cross-compiling C++ is hard.** Sysroots, libc, linker flavors. Budget a full day if it's your first time.

### Resources

- "Toolchains": <https://bazel.build/extending/toolchains>
- "Platforms": <https://bazel.build/extending/platforms>
- toolchains_llvm: <https://github.com/bazel-contrib/toolchains_llvm>

---

## Module 15 — Debugging and Profiling

**Time:** 3–4 hours.

### Concepts

The tools to know:

- **`bazel query`** — static analysis of the target graph. "What depends on X?" "Why is Y in this build?"
- **`bazel cquery`** — like query, but post-configuration. Sees the actual configured targets including selects.
- **`bazel aquery`** — action-level. "What's the actual command line for this compile?" "What env vars does it run with?"
- **`bazel info`** — paths and metadata.
- **`--explain=log.txt --verbose_explanations`** — Bazel writes, for each action, *why* it had to re-run.
- **`--sandbox_debug`** — leaves the sandbox dir behind on failure so you can `cd` in and reproduce.
- **`--subcommands`** — print every command as it runs.

### Hands-on

Take a build you've written and intentionally break it in three ways:

1. Add a hidden dependency (a header used but not in `hdrs`). Watch sandbox catch it. Use `--sandbox_debug` to see how.
2. Make an action non-hermetic (read `$HOME` or `date`). Watch the cache misbehave. Use `--explain` to detect.
3. Cause a select to resolve unexpectedly. Use `cquery` to debug.

For each, the goal is *fluency with the diagnostic flags*, not just fixing the bug.

### Pitfalls

- `bazel query` doesn't see selects — `cquery` does. Pick the right one.
- `aquery` output is verbose. Use `--output=text` and `--include_artifacts=false` to filter.

### Resources

- "Query reference": <https://bazel.build/query/quickstart>
- "Common build issues": <https://bazel.build/configure/common>

---

## Module 16 — Migrating an Existing Codebase

**Time:** Variable. Read this whether or not you're migrating right now.

### Concepts

Adopting Bazel into an existing project is hard. The hard parts are not technical:

- **Convincing your team.** Bazel is unfamiliar. Build error messages are alien. The ROI is in the long term and on large codebases. On a small, single-language project, it's not worth it.
- **Picking a strategy.** The options:
  - **Big bang** — full conversion in one PR. Only viable for very small projects.
  - **Side-by-side** — keep the existing build, add a Bazel build that produces the same artifacts. Switch CI to Bazel once it's passing. Most common approach for medium-size projects.
  - **Per-language** — convert one language at a time. Workable if your build is already modular per-language.
- **Auto-generators.** `gazelle` for Go (and other languages via plugins). `BUILD` file generators exist for Java, Python, JS. Use them — manual `BUILD` writing for thousands of files is brutal.

### Hands-on

Pick a small open-source project (a few thousand lines of one language) and write a Bazel build for it. Match the existing build's outputs. Notice everything that breaks: undeclared deps, environment assumptions, generated files, toolchain quirks. This is what migration is.

### Pitfalls

- **The first 80% takes 20% of the time.** The last 20% — every weird edge case in the existing build — takes the rest.
- **Don't fight the existing layout.** Bazel works fine with non-Bazel directory conventions. You don't need to restructure your whole repo.

### Resources

- "Migration": <https://bazel.build/migrate>
- gazelle: <https://github.com/bazel-contrib/bazel-gazelle>

---

## Module 17 — The Ecosystem and What's Next

**Time:** Ongoing.

### Concepts

People to follow / watch talks from: the Bazel team's blog (blog.bazel.build), EngFlow's blog, BuildBuddy's blog, Aspect Build's blog. BazelCon happens annually; recordings are on YouTube and worth your time.

Tools that orbit Bazel:

- **buildifier / buildozer** — formatters and bulk-editors for `BUILD` files.
- **gazelle** — `BUILD` generator.
- **ibazel** — file watcher; reruns Bazel commands on change.
- **Aspect CLI** — opinionated UX layer over Bazel.
- **rules_oci** — modern Docker/OCI image rules (replacing rules_docker, which is deprecated).

Where Bazel is going (as of early 2026):

- The new Mintlify-powered docs site at preview.bazel.build.
- A new web UI for the BCR.
- Continued improvements to Bzlmod ergonomics, lockfile handling, and Dependabot-style dependency updates.
- Skyfocus (experimental memory reduction) for very large workspaces.
- Symbolic macros becoming the standard.

### Hands-on

Subscribe to the Bazel blog. Watch one BazelCon talk per month for six months. Pick a ruleset on GitHub and read all of its source. Read 10 closed pull requests in the bazelbuild/bazel repo to get a feel for what active development looks like.

---

# Capstone Project

You're an expert when you can do this from scratch in a weekend.

**The brief:** Build a polyglot monorepo with Bazel. Requirements:

1. **Three languages.** A Go backend service, a TypeScript frontend, and a Python data-processing job. Each has libraries, binaries, and tests.
2. **Cross-language artifact.** A protobuf schema in `//proto/...` that generates Go, TypeScript, and Python bindings. All three apps consume it. Changing the proto rebuilds only the affected downstream.
3. **External deps.** At least one Maven artifact (or a similar non-trivial ecosystem package), one pip package, and one npm package. Lockfile committed.
4. **A custom rule.** Write a rule that takes a YAML config file and generates a Go and a TypeScript file from it, both used by your services. Use it in your build.
5. **Hermetic toolchains.** All three languages use hermetic toolchains. Verify by running the build in a clean Docker container with no system toolchains.
6. **Tests with coverage.** Every library has unit tests. `bazel coverage //...` produces meaningful output.
7. **Cross-compilation.** Build the Go binary for both `linux_amd64` and `linux_arm64` via `--platforms=`.
8. **Container image.** Use rules_oci to package the Go service into an OCI image, hermetically (no Dockerfile).
9. **Remote cache.** The build uses a remote cache (bazel-remote run locally is fine). Document the cache hit rate on a clean second build.
10. **CI.** A GitHub Actions workflow that runs `bazel test //...` on push, with the remote cache configured.

**Stretch goals:**

- An aspect that produces a JSON manifest of all targets and their transitive dependencies for security scanning.
- A custom build flag (`--//config:env=prod`) that changes which configuration files get embedded into the binaries via `select()`.
- A `bazel run //tools:format` target that runs buildifier and your language formatters across the repo.

When you can do this, write up the lessons learned. That's a solid technical blog post and concrete proof of skill.

---

# Quick Reference: When You're Stuck

| Symptom | First thing to try |
|---|---|
| "no such target //x:y" | `bazel query //x:all` to see what's actually there |
| "target X is not visible" | Check the `visibility` attr on X |
| Build is slow | `bazel build //... --profile=p.gz`, open in `ui.perfetto.dev` |
| Tests pass locally, fail in CI | Hermeticity bug; run with `--sandbox_debug` |
| Cache miss when expected hit | `bazel build --explain=log.txt`; diff inputs between runs |
| "this target is missing dep on @rules_..." | Add the `bazel_dep` and `use_repo` to `MODULE.bazel` |
| Can't figure out what command Bazel is running | `bazel build //x:y --subcommands` |
| Want to know why X is in the build | `bazel query 'somepath(//top:target, //x:y)'` |

---

# Reading List

- **Official docs**, in order of usefulness: bazel.build/concepts, bazel.build/extending, bazel.build/external, bazel.build/configure.
- ***Software Engineering at Google***, chapters 18–23. Free online. The "why" behind a lot of Bazel's design.
- **Bazel team blog** — blog.bazel.build.
- **EngFlow blog** — particularly good on migration and large-scale topics.
- **Aspect Build's "Bazel Notes"** — opinionated but useful.
- The source code of `bazel_skylib`, `rules_python`, and one full-featured ruleset of your choice. Reading rules is how rule-writing becomes natural.

---

*Built for Bazel 9.x. Future versions will move faster than this document; check the official roadmap when starting.*
