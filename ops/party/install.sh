#!/usr/bin/env bash
set -euo pipefail

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

[[ $EUID -eq 0 ]] || fail "run as root"
[[ $# -eq 1 ]] || fail "usage: install.sh <40-char-release-sha>"

release_sha="$1"
[[ "$release_sha" =~ ^[0-9a-f]{40}$ ]] || fail "release SHA must be 40 lowercase hexadecimal characters"

for command_name in awk caddy cat cmp cp curl grep install ln mktemp mv readlink rm systemctl tar; do
    command -v "$command_name" >/dev/null 2>&1 || fail "required command not found: $command_name"
done

base="/srv/userspace-party"
release_dir="$base/releases/$release_sha"
current="$base/current"
caddyfile="/etc/caddy/Caddyfile"
managed_site="/etc/caddy/userspace-party.caddy"
managed_import='import /etc/caddy/userspace-party.caddy'
raw_base="https://raw.githubusercontent.com/ze-gois/rust_userspace_hub/$release_sha"
archive_url="https://github.com/ze-gois/rust_userspace_hub/archive/$release_sha.tar.gz"

[[ -f "$caddyfile" && ! -L "$caddyfile" ]] || fail "expected regular /etc/caddy/Caddyfile"

work_dir="$(mktemp -d)"
candidate_site="$work_dir/userspace-party.caddy"
candidate_root="$work_dir/Caddyfile"
previous_root="$work_dir/Caddyfile.previous"
previous_site="$work_dir/userspace-party.caddy.previous"
previous_current="$work_dir/current.previous"
had_site=false
had_current=false

cleanup() {
    rm -rf -- "$work_dir"
}
trap cleanup EXIT

archive="$work_dir/source.tar.gz"
site_dir="$work_dir/site"

curl --fail --silent --show-error --location \
    "$archive_url" \
    -o "$archive"

install -d -m 0755 "$site_dir"
tar -xzf "$archive" \
    --strip-components=2 \
    -C "$site_dir" \
    "rust_userspace_hub-$release_sha/party"

curl --fail --silent --show-error --location \
    "$raw_base/ops/party/userspace-party.caddy" \
    -o "$candidate_site"

grep -Fq '<title>userspace.party</title>' "$site_dir/index.html" \
    || fail "downloaded landing page failed identity check"
grep -Fq 'userspace.party {' "$candidate_site" \
    || fail "downloaded Caddy site failed identity check"

for route in hub ample userspace userspace_build kernelspace humans webspace twins computers; do
    [[ -f "$site_dir/$route/index.html" ]] \
        || fail "missing landing page for /$route"
done
[[ -f "$site_dir/assets/crate.css" ]] \
    || fail "missing shared crate stylesheet"

install -d -m 0755 -o root -g root "$base/releases"
rm -rf -- "$release_dir"
install -d -m 0755 -o root -g root "$release_dir"
cp -a "$site_dir/." "$release_dir/"
find "$release_dir" -type d -exec chmod 0755 {} +
find "$release_dir" -type f -exec chmod 0644 {} +

cp -a "$caddyfile" "$previous_root"
if [[ -f "$managed_site" ]]; then
    cp -a "$managed_site" "$previous_site"
    had_site=true
fi
if [[ -L "$current" ]]; then
    readlink "$current" > "$previous_current"
    had_current=true
elif [[ -e "$current" ]]; then
    fail "$current exists but is not a symlink"
fi

# Refuse duplicate ownership outside the managed site.
if grep -Fq 'userspace.party' "$caddyfile"; then
    fail "root Caddyfile already contains userspace.party outside the managed site"
fi

awk -v managed="$managed_import" '$0 != managed { print }' "$caddyfile" > "$candidate_root"
printf '\nimport %s\n' "$candidate_site" >> "$candidate_root"
caddy validate --config "$candidate_root" --adapter caddyfile

install -m 0644 -o root -g root "$candidate_site" "$managed_site"

if ! grep -Fqx "$managed_import" "$caddyfile"; then
    root_tmp="$(mktemp /etc/caddy/.Caddyfile.userspace-party.XXXXXX)"
    cp -a "$caddyfile" "$root_tmp"
    printf '\n%s\n' "$managed_import" >> "$root_tmp"
    install -m 0644 -o root -g root "$root_tmp" "$caddyfile"
    rm -f -- "$root_tmp"
fi

new_link="$base/.current.$$"
ln -s "releases/$release_sha" "$new_link"
mv -Tf "$new_link" "$current"

rollback() {
    printf 'ERROR: deploy failed; restoring previous state\n' >&2
    install -m 0644 -o root -g root "$previous_root" "$caddyfile"
    if [[ "$had_site" == "true" ]]; then
        install -m 0644 -o root -g root "$previous_site" "$managed_site"
    else
        rm -f -- "$managed_site"
    fi
    if [[ "$had_current" == "true" ]]; then
        ln -sfn "$(cat "$previous_current")" "$current"
    else
        rm -f -- "$current"
    fi
    caddy validate --config "$caddyfile" --adapter caddyfile >/dev/null 2>&1 || true
    systemctl reload caddy >/dev/null 2>&1 || true
    exit 1
}

caddy validate --config "$caddyfile" --adapter caddyfile || rollback
systemctl reload caddy || rollback
systemctl is-active --quiet caddy || rollback
cmp -s "$candidate_site" "$managed_site" || rollback

printf 'userspace.party deployed\n'
printf 'release: %s\n' "$release_sha"
printf 'current: %s -> %s\n' "$current" "$(readlink "$current")"
printf 'site: %s\n' "$managed_site"
printf 'caddy: active\n'
printf 'next: point userspace.party DNS at this VPS and verify public HTTPS\n'
