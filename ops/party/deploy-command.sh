#!/usr/bin/env bash
set -euo pipefail

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

original="${SSH_ORIGINAL_COMMAND:-}"
read -r verb arg extra <<<"$original"

case "$verb" in
    probe)
        [[ -z "${arg:-}" && -z "${extra:-}" ]] || fail "probe takes no arguments"
        printf 'userspace.party deployment channel ready\n'
        ;;
    deploy)
        [[ -n "${arg:-}" && -z "${extra:-}" ]] || fail "usage: deploy <40-char-release-sha>"
        [[ "$arg" =~ ^[0-9a-f]{40}$ ]] || fail "invalid release SHA"
        exec sudo -n /usr/local/libexec/userspace-party/deploy-root.sh "$arg"
        ;;
    *)
        fail "unsupported deployment command"
        ;;
esac
