# userspace.party production

The public site is deployed from the `party/` tree to `zegois-core` as an immutable release.

## Production layout

```text
/srv/userspace-party/
├── releases/<git-sha>/
│   ├── index.html
│   ├── assets/
│   ├── hub/
│   ├── ample/
│   ├── userspace/
│   ├── userspace_build/
│   ├── kernelspace/
│   ├── humans/
│   ├── webspace/
│   ├── twins/
│   ├── computers/
│   └── .well-known/userspace-party-release
└── current -> releases/<git-sha>
```

Caddy serves `/srv/userspace-party/current`.

## CI

`.github/workflows/publication-unit.yml` runs on pull requests and pushes to `main`.
It validates the deployment scripts, verifies the complete static route tree, runs the
publication tests and inspects the coordinated crate graph.

## CD

`.github/workflows/party-production.yml` runs automatically after a successful
`Publication Unit` push on `main`.

The workflow:

1. resolves the exact Git commit SHA;
2. connects with a dedicated `userspace-party-deploy` SSH identity;
3. uses the restricted `deploy <sha>` forced command;
4. installs `party/` into an immutable release directory;
5. atomically updates `current`;
6. validates and reloads Caddy;
7. verifies the root and all nine crate routes over public HTTPS;
8. verifies that `/.well-known/userspace-party-release` exactly matches the deployed SHA.

The workflow also supports manual `workflow_dispatch` for an explicit release SHA.

## One-time bootstrap

After these files are present on `main`, run from an administrative workstation that
already has trusted SSH access to `zegois-core`:

```bash
git switch main
git pull --ff-only
bash ops/party/bootstrap-production-cd.sh zegois-core
```

The bootstrap:

- creates or updates the dedicated `userspace-party-deploy` account;
- installs the root-owned forced-command deployment wrappers;
- generates a dedicated Ed25519 deployment key;
- pins the VPS host key from the workstation's existing trusted `known_hosts`;
- creates the GitHub Environment `userspace-party-production`;
- stores the SSH private key and known-hosts entry as Environment secrets;
- stores the host, port and deploy user as Environment variables;
- verifies the restricted channel with `probe`.

The generated private key exists locally only inside a temporary directory and is removed
when the bootstrap exits.

## Restricted SSH surface

The deployment key cannot request a general shell. It accepts only:

```text
probe
deploy <40-character-git-sha>
```

The root deployment wrapper validates the SHA, downloads the installer from that exact
repository revision, validates its identity and shell syntax, and then executes the
immutable release installation.
