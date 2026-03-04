#!/usr/bin/env bash
set -euo pipefail

echo "[1/4] cargo fmt --all -- --check"
cargo fmt --all -- --check

echo "[2/4] cargo clippy --all-targets --all-features -- -D warnings"
cargo clippy --all-targets --all-features -- -D warnings

echo "[3/4] cargo test --all-targets --all-features"
cargo test --all-targets --all-features

echo "[4/4] cargo publish --dry-run --allow-dirty"
cargo publish --dry-run --allow-dirty

echo "local_check completed"
