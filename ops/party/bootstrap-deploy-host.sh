#!/usr/bin/env bash
set -euo pipefail

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

[[ $EUID -eq 0 ]] || fail "run as root"
[[ $# -eq 2 ]] || fail "usage: bootstrap-deploy-host.sh <public-key-base64> <source-dir>"

public_key_b64="$1"
source_dir="$2"
deploy_user="userspace-party-deploy"
libexec_dir="/usr/local/libexec/userspace-party"
sudoers_file="/etc/sudoers.d/userspace-party-deploy"

for command_name in base64 cut getent id install mkdir passwd printf useradd usermod visudo; do
    command -v "$command_name" >/dev/null 2>&1 || fail "required command not found: $command_name"
done

for required in deploy-command.sh deploy-root.sh; do
    [[ -f "$source_dir/$required" ]] || fail "missing bootstrap payload: $required"
done

if ! id "$deploy_user" >/dev/null 2>&1; then
    useradd --create-home --shell /bin/bash "$deploy_user"
fi
passwd -l "$deploy_user" >/dev/null 2>&1 || true

home_dir="$(getent passwd "$deploy_user" | cut -d: -f6)"
[[ -n "$home_dir" ]] || fail "could not resolve deploy user home"

install -d -m 0755 -o root -g root "$libexec_dir"
install -m 0755 -o root -g root "$source_dir/deploy-command.sh" "$libexec_dir/deploy-command.sh"
install -m 0755 -o root -g root "$source_dir/deploy-root.sh" "$libexec_dir/deploy-root.sh"

public_key="$(printf '%s' "$public_key_b64" | base64 --decode)"
[[ "$public_key" == ssh-ed25519\ * ]] || fail "expected an Ed25519 public key"

install -d -m 0700 -o "$deploy_user" -g "$deploy_user" "$home_dir/.ssh"
authorized_keys="$home_dir/.ssh/authorized_keys"
printf 'no-agent-forwarding,no-port-forwarding,no-X11-forwarding,no-pty,command="%s" %s\n' \
    "$libexec_dir/deploy-command.sh" "$public_key" > "$authorized_keys"
chown "$deploy_user:$deploy_user" "$authorized_keys"
chmod 0600 "$authorized_keys"

cat > "$sudoers_file" <<SUDOERS
$deploy_user ALL=(root) NOPASSWD: $libexec_dir/deploy-root.sh *
SUDOERS
chmod 0440 "$sudoers_file"
visudo -cf "$sudoers_file" >/dev/null || fail "invalid sudoers policy"

printf 'userspace.party production deployment channel installed\n'
printf 'user: %s\n' "$deploy_user"
printf 'commands: probe, deploy <sha>\n'
