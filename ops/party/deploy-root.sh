#!/usr/bin/env bash
set -euo pipefail

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

[[ $EUID -eq 0 ]] || fail "deploy-root must run as root"
[[ $# -eq 1 ]] || fail "usage: deploy-root.sh <40-char-release-sha>"

release_sha="$1"
[[ "$release_sha" =~ ^[0-9a-f]{40}$ ]] || fail "invalid release SHA"

for command_name in bash curl grep mktemp rm; do
    command -v "$command_name" >/dev/null 2>&1 || fail "required command not found: $command_name"
done

tmp_dir="$(mktemp -d)"
cleanup() {
    rm -rf -- "$tmp_dir"
}
trap cleanup EXIT

installer="$tmp_dir/install.sh"
installer_url="https://raw.githubusercontent.com/ze-gois/rust_userspace_hub/$release_sha/ops/party/install.sh"

curl --fail --silent --show-error --location "$installer_url" -o "$installer"
grep -Fq 'base="/srv/userspace-party"' "$installer" \
    || fail "downloaded installer failed identity check"
bash -n "$installer"

bash "$installer" "$release_sha"
