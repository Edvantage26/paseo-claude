# paseo-claude — Docker image for Paseo + Claude Code

Self-hosted [Paseo](https://paseo.sh) daemon with [Claude Code](https://docs.anthropic.com/en/docs/claude-code) preinstalled, published to GitHub Container Registry.

## Image

```
ghcr.io/edvantage26/paseo-claude:latest
```

Tags: `latest`, `vX.Y.Z`, `vX.Y`, `sha-<commit>`. Multi-arch: `linux/amd64`, `linux/arm64`.

## Quick start

The container does not expose any ports by default — it connects outbound to the Paseo relay. You only need volumes:

```bash
docker run -d --name paseo \
  -v paseo-home:/home/paseo/.paseo \
  -v claude-home:/home/paseo/.claude \
  -v "$PWD":/workspace \
  ghcr.io/edvantage26/paseo-claude:latest
```

Authenticate Claude Code once (it stores its OAuth tokens in the `claude-home` volume):

```bash
docker exec -it paseo claude /login
```

## Connecting clients

### Relay (recommended, default)

```bash
docker exec -it paseo paseo daemon pair
```

Scan the QR code with the Paseo mobile or desktop app. The daemon dials out to the relay; no inbound ports, no firewall config.

### Direct LAN/VPN connection (optional)

Only if you know what you're doing. Republish the port and set a password:

```bash
docker run -d --name paseo \
  -p 6767:6767 \
  -e PASEO_PASSWORD=your-strong-secret \
  -v paseo-home:/home/paseo/.paseo \
  -v claude-home:/home/paseo/.claude \
  -v "$PWD":/workspace \
  ghcr.io/edvantage26/paseo-claude:latest
```

Then connect with `paseo --host "tcp://<host>:6767?password=your-strong-secret" ls`.

## Volumes — important

- `/home/paseo/.paseo` — daemon keys, sessions, config. Persist this.
- `/home/paseo/.claude` — **Claude Code OAuth tokens.** Persist this, never bake into the image.
- `/home/paseo/.ssh` — container-local SSH key for git. Persist this. The image ships with `known_hosts` for github.com pre-populated, so the first `git clone` will not prompt.
- `/workspace` — your code. Bind-mount the project directory you want the agents to work on.

## SSH setup for GitHub

The container uses its own SSH key (stored in the `paseo-ssh` named volume), not your host's keys. Set it up once after the container is running:

```bash
# 1. Generate a key inside the container
docker exec -it paseo ssh-keygen -t ed25519 -C "paseo@$(hostname)" -f /home/paseo/.ssh/id_ed25519 -N ""

# 2. Print the public key — add it to https://github.com/settings/keys
docker exec paseo cat /home/paseo/.ssh/id_ed25519.pub

# 3. Verify
docker exec paseo ssh -T git@github.com
# Expected: "Hi <user>! You've successfully authenticated..."
```

After that, agents inside the container can `git clone git@github.com:Org/Repo.git` and `git push` in `/workspace` without further setup. The key persists in the `paseo-ssh` volume across container recreates.

## Build locally

```bash
docker build -t paseo-claude:dev .
docker compose up -d
```

## Publishing

Push to `main` builds and tags `latest`. Push a tag like `v0.1.0` builds the semver tags. The workflow signs each image with a build-provenance attestation.

## Security notes

- The image runs as non-root user `paseo` (UID 1000).
- Default deployment exposes nothing to the network — connections happen via the Paseo relay.
- Treat the `claude-home` volume like a credential. Anyone with access can use your Anthropic account.

## License

The Dockerfile and CI config in this repo: MIT (see `LICENSE`). Paseo itself is AGPL-3.0; Claude Code follows Anthropic's terms. If you offer this container as a service to third parties, AGPL requires you to make the source available to them.
