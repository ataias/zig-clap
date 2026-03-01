# CLAUDE.md

## Build commands

```bash
zig build            # Run all tests + build examples (default step)
zig build test       # Run tests in all optimization modes
zig build examples   # Build all example programs
zig build docs       # Generate API docs to zig-out/docs/
```

## Testing

Tests are embedded in source files using Zig's `test` blocks. The main file
`clap.zig` re-exports all submodules so `zig build test` runs everything.

```bash
zig build test                        # via build system
zig test clap.zig                     # directly (Debug)
zig test clap.zig -OReleaseSafe       # specific optimization mode
```

CI runs tests in all four modes: Debug, ReleaseSmall, ReleaseSafe, ReleaseFast.

## Linting

```bash
zig fmt --check .    # check formatting (CI uses this)
zig fmt .            # auto-format
```

## Coverage

Coverage uses `kcov` running inside a Linux container (kcov requires ptrace/Linux).

**Local (macOS or any system with a container runtime):**

```bash
./scripts/coverage.sh
```

The script auto-detects the container runtime: prefers
[apple/container](https://github.com/apple/container) if installed, falls back
to `docker`. It builds a Debian-based image from `Containerfile.coverage` with
kcov and the latest Zig nightly, then runs tests under kcov. The image is
cached by a hash of the Containerfile — only rebuilt when the file changes.

Report output: `zig-out/coverage/index.html`

**CI:** The GitHub Actions coverage job runs in a `debian:trixie-slim` container
with `-fllvm` (Zig's self-hosted x86 backend emits DWARF that kcov can't parse).
Coverage threshold: **97%**.

## Project structure

```
clap.zig                    # Main library (public API, parse/help/usage)
clap/
  streaming.zig             # Low-level streaming argument parser
  args.zig                  # Argument iterator types
  parsers.zig               # Value parsers (string → int/float/enum)
  codepoint_counting_writer.zig  # Unicode-aware writer for help alignment
example/                    # 6 runnable examples
scripts/coverage.sh         # Local coverage runner (container-based)
Containerfile.coverage      # Container image for kcov coverage
build.zig                   # Build configuration
build.zig.zon               # Package manifest (v0.11.0)
```

## Key patterns

- **No external dependencies** — pure Zig standard library only.
- **Comptime DSL** — CLI flags are declared as comptime strings parsed into
  typed `Param` arrays. No runtime string maps.
- **Minimum Zig version** — `0.16.0-dev.2261+d6b3dd25a` (tracked in `build.zig.zon`).
- **Upstream remote** — `upstream` points to `Hejsil/zig-clap` (`master` branch),
  `origin` is this fork (`main` branch).
