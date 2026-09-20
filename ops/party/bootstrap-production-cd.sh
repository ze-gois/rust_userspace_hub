#!/usr/bin/env bash
set -euo pipefail

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

usage() {
    cat <<'USAGE'
Usage: bootstrap-production-cd.sh [admin-ssh-target]

Creates the dedicated GitHub Actions -> userspace.party production deployment
channel. The SSH target defaults to "zegois-core".

Prerequisites:
- verified administrative SSH access to the production host;
- gh authenticated with admin access to ze-gois/rust_userspace_hub;
- sudo access on the production host.

The generated private deployment key is uploaded directly to the
userspace-party-production GitHub Environment and removed locally on exit.
USAGE
}

[[ $# -le 1 ]] || {
    usage >&2
    exit 2
}

admin_target="${1:-zegois-core}"
repository="ze-gois/rust_userspace_hub"
environment="userspace-party-production"
deploy_user="userspace-party-deploy"

for command_name in awk base64 gh grep mktemp scp ssh ssh-keygen; do
    command -v "$command_name" >/dev/null 2>&1 || fail "required command not found: $command_name"
done

gh auth status --hostname github.com >/dev/null 2>&1 \
    || fail "gh is not authenticated to github.com"

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/../.." && pwd)"
cd "$repo_root"

for required in \
    ops/party/bootstrap-deploy-host.sh \
    ops/party/deploy-command.sh \
    ops/party/deploy-root.sh; do
    [[ -f "$required" ]] || fail "required bootstrap file missing: $required"
done

ssh_config="$(ssh -G "$admin_target")"
production_host="$(awk '$1 == "hostname" { print $2; exit }' <<<"$ssh_config")"
production_port="$(awk '$1 == "port" { print $2; exit }' <<<"$ssh_config")"

[[ -n "$production_host" ]] || fail "could not resolve SSH hostname"
[[ "$production_port" =~ ^[0-9]+$ ]] || fail "could not resolve SSH port"

if [[ "$production_port" == "22" ]]; then
    known_hosts_target="$production_host"
else
    known_hosts_target="[$production_host]:$production_port"
fi

trusted_key_blob="$(
    ssh-keygen -F "$known_hosts_target" 2>/dev/null \
        | awk '$2 == "ssh-ed25519" { print $3; exit }'
)"

if [[ -z "$trusted_key_blob" && "$admin_target" != "$known_hosts_target" ]]; then
    trusted_key_blob="$(
        ssh-keygen -F "$admin_target" 2>/dev/null \
            | awk '$2 == "ssh-ed25519" { print $3; exit }'
    )"
fi

[[ -n "$trusted_key_blob" ]] \
    || fail "no trusted Ed25519 host key for $admin_target found in known_hosts"

tmp_dir="$(mktemp -d)"
remote_tmp="/tmp/userspace-party-cd-bootstrap-$$"
cleanup() {
    rm -rf -- "$tmp_dir"
    ssh "$admin_target" "rm -rf -- '$remote_tmp'" >/dev/null 2>&1 || true
}
trap cleanup EXIT

deploy_key="$tmp_dir/id_ed25519"
known_hosts_file="$tmp_dir/known_hosts"

printf '%s ssh-ed25519 %s\n' "$known_hosts_target" "$trusted_key_blob" > "$known_hosts_file"
ssh-keygen -F "$known_hosts_target" -f "$known_hosts_file" >/dev/null \
    || fail "generated known_hosts entry cannot be resolved by OpenSSH"

ssh \
    -o StrictHostKeyChecking=yes \
    -o UserKnownHostsFile="$known_hosts_file" \
    "$admin_target" \
    true \
    || fail "known_hosts preflight failed"

ssh-keygen \
    -q \
    -t ed25519 \
    -N '' \
    -C "userspace-party-production-deployment" \
    -f "$deploy_key"

ssh "$admin_target" "umask 077; mkdir -p '$remote_tmp'"
scp \
    ops/party/bootstrap-deploy-host.sh \
    ops/party/deploy-command.sh \
    ops/party/deploy-root.sh \
    "$admin_target:$remote_tmp/"

public_key_b64="$(base64 -w0 "$deploy_key.pub")"

echo
echo "Installing restricted userspace.party deployment channel on $admin_target."
echo "sudo may ask for your production-host password once."
ssh -t "$admin_target" \
    "sudo bash '$remote_tmp/bootstrap-deploy-host.sh' '$public_key_b64' '$remote_tmp'"

ssh \
    -T \
    -i "$deploy_key" \
    -o BatchMode=yes \
    -o IdentitiesOnly=yes \
    -o StrictHostKeyChecking=yes \
    -o UserKnownHostsFile="$known_hosts_file" \
    -p "$production_port" \
    "$deploy_user@$production_host" \
    probe \
    | grep -Fqx 'userspace.party deployment channel ready' \
    || fail "restricted deployment channel probe failed"

gh api --method PUT "repos/$repository/environments/$environment" >/dev/null

gh secret set PARTY_SSH_PRIVATE_KEY \
    --repo "$repository" \
    --env "$environment" \
    < "$deploy_key"

gh secret set PARTY_SSH_KNOWN_HOSTS \
    --repo "$repository" \
    --env "$environment" \
    < "$known_hosts_file"

gh variable set PARTY_SSH_HOST \
    --repo "$repository" \
    --env "$environment" \
    --body "$production_host"

gh variable set PARTY_SSH_PORT \
    --repo "$repository" \
    --env "$environment" \
    --body "$production_port"

gh variable set PARTY_SSH_USER \
    --repo "$repository" \
    --env "$environment" \
    --body "$deploy_user"

echo
echo "userspace.party production CD bootstrap complete."
echo "repository: $repository"
echo "environment: $environment"
echo "deploy user: $deploy_user"
echo "restricted verbs: probe, deploy <sha>"
echo "private key: stored only as a GitHub Environment secret after exit"
