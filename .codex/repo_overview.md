# Repository Overview

## 1. High-Level Purpose
This repository provides a Rust CLI package centered around `gtc`, a thin command router for Greentic tooling. The package now ships only the `gtc` binary, with delegation to separately installed external tools (`greentic-dev`, `greentic-operator`).

Implementation is intentionally lightweight and mostly stdlib-based: argument parsing, subprocess passthrough, and integration tests that use fake binaries in `PATH` to validate routing behavior.

## 2. Main Components and Functionality
- **Path:** `Cargo.toml`
- **Role:** Crate manifest and packaging metadata.
- **Key functionality:**
- Declares package `gtc` version `1.0.0-alpha1`.
- Declares binary: `gtc`.
- Defines `cargo-binstall` metadata (`pkg-url`, `bin-dir`, archive format overrides for Windows) to consume GitHub release assets.
- **Key dependencies / integration points:**
- No external Rust crate dependencies; code uses Rust stdlib only.

- **Path:** `src/bin/gtc.rs`
- **Role:** Primary CLI router.
- **Key functionality:**
- Supports `dev`, `op|operator`, `wizard`, `install`, `doctor`, `version`, and help.
- `gtc --version` / `gtc version` prints `CARGO_PKG_VERSION`.
- `gtc dev <args...>` and `gtc op <args...>` are direct passthrough to downstream binaries with inherited stdin/stdout/stderr and propagated exit codes.
- `gtc install tools` calls `greentic-dev install tools`.
- `gtc wizard` supports explicit routing (`dev`, `op`) and smart routing (`run --target ...`).
- Smart routing validates targets early and routes:
- `pack|component|flow|dev` to `greentic-dev wizard run ...`
- `operator|bundle` to operator wizard flow with one retry fallback (`wizard` then `demo wizard`) only when stderr matches clap-style unknown-subcommand text.
- `gtc doctor` checks for `greentic-dev` and `greentic-operator` on PATH and prints version output when available.
- **Key dependencies / integration points:**
- Requires external `greentic-dev` and `greentic-operator` binaries discoverable on `PATH`.

- **Path:** `tests/gtc_router_integration.rs`
- **Role:** Unix integration tests for router/passthrough behavior.
- **Key functionality:**
- Creates temporary fake binaries/scripts in `PATH` to verify dispatch.
- Covers `--version`, dev passthrough, exit code propagation, smart wizard routing, unknown target rejection, and operator fallback retry.
- **Key dependencies / integration points:**
- Unix-only test harness (`#![cfg(unix)]`).

- **Path:** `ci/local_check.sh`
- **Role:** Local preflight script.
- **Key functionality:**
- Runs `cargo fmt --all -- --check`.
- Runs `cargo clippy --all-targets --all-features -- -D warnings`.
- Runs `cargo test --all-targets --all-features`.
- Runs `cargo publish --dry-run --allow-dirty`.

- **Path:** `.github/workflows/ci.yml`
- **Role:** Continuous integration workflow.
- **Key functionality:**
- Triggers on push and pull request.
- Runs `fmt`, `clippy`, and `test` as separate jobs (parallel execution).

- **Path:** `.github/workflows/release.yml`
- **Role:** Publish and release workflow.
- **Key functionality:**
- Triggers on push to `master` and manual dispatch.
- Runs `fmt`, `clippy`, and `test` in parallel gates.
- Publishes crate to crates.io (`cargo publish`) after gates pass.
- Builds release binaries for Linux x86_64, macOS x86_64, macOS aarch64, Windows x86_64, Windows aarch64.
- Packages artifacts as `gtc-<target>.tgz|zip` containing only `gtc`.
- Creates GitHub release named with Cargo version and tag `v<version>`, uploads build artifacts.
- **Key dependencies / integration points:**
- Requires `secrets.CARGO_REGISTRY_TOKEN`.
- Release artifact names/paths are aligned with `[package.metadata.binstall]` in `Cargo.toml`.

- **Path:** `docs/gtc-wizard.md`
- **Role:** Wizard routing behavior reference.
- **Key functionality:**
- Documents explicit and smart wizard modes, operator fallback logic, PATH-only discovery, and `doctor` scope.

## 3. Work In Progress, TODOs, and Stubs
- **Location:** `docs/gtc-wizard.md:94`
- **Status:** TODO
- **Short description:** Compatibility floor for `greentic-dev` is still placeholder text (`>= TODO`).

- **Location:** `docs/gtc-wizard.md:95`
- **Status:** TODO
- **Short description:** Compatibility floor for `greentic-operator` is still placeholder text (`>= TODO`).

## 4. Broken, Failing, or Conflicting Areas
- **Location:** local checks (`cargo fmt`, `cargo clippy`, `cargo test`, `cargo publish --dry-run`)
- **Evidence:** Latest local runs pass.
- **Likely cause / nature of issue:** No currently confirmed build/test breakage in the checked local environment.

- **Location:** `.github/workflows/release.yml` (`publish_crates` on every push to `master`)
- **Evidence:** Workflow always runs `cargo publish` after checks on `master`.
- **Likely cause / nature of issue:** After a version is published once, subsequent `master` pushes without a version bump will likely fail publish with “version already exists,” causing release workflow failures until `Cargo.toml` version changes.

- **Location:** `gtc` runtime dependency on external tools (`greentic-dev`, `greentic-operator`)
- **Evidence:** Core routing paths fail when those binaries are not installed; `gtc` prints install guidance.
- **Likely cause / nature of issue:** `gtc` is intentionally a router, so core functionality depends on separately published downstream CLIs.

## 5. Notes for Future Work
- Fill compatibility version placeholders in `docs/gtc-wizard.md`.
- Decide release policy for `master` pushes (for example publish only on version tags, or add a guard that checks crates.io version before publishing).
- Keep README and wizard docs synchronized with the split-install model (`gtc` + separately installed delegated tools).
