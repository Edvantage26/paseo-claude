# syntax=docker/dockerfile:1.7

FROM node:22-bookworm-slim

# Tools that agents commonly need inside the container
RUN apt-get update && apt-get install -y --no-install-recommends \
      git \
      curl \
      ca-certificates \
      openssh-client \
      ripgrep \
      jq \
      tini \
      sudo \
    && rm -rf /var/lib/apt/lists/*

# Install Paseo CLI and Claude Code globally
RUN npm install -g \
      @getpaseo/cli \
      @anthropic-ai/claude-code \
    && npm cache clean --force

# Non-root user (UID 1000 lines up with most Linux hosts for bind-mount perms).
# The node base image ships with its own UID 1000 user (`node`) — remove it
# first so paseo can claim 1000.
RUN userdel -r node 2>/dev/null || true \
    && useradd -m -u 1000 -s /bin/bash paseo \
    && echo "paseo ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/paseo

USER paseo
WORKDIR /workspace

# Where Paseo and Claude Code keep state — declare as volumes so they persist.
# `~/.ssh` is also a named volume so a container-local SSH key persists across
# container recreates without leaking the host's keys into the image.
ENV PASEO_HOME=/home/paseo/.paseo
ENV PASEO_LISTEN=0.0.0.0:6767
RUN mkdir -p /home/paseo/.paseo /home/paseo/.claude /home/paseo/.ssh \
    && chmod 700 /home/paseo/.ssh \
    && ssh-keyscan -t ed25519,ecdsa,rsa github.com > /home/paseo/.ssh/known_hosts 2>/dev/null \
    && chmod 600 /home/paseo/.ssh/known_hosts
VOLUME ["/home/paseo/.paseo", "/home/paseo/.claude", "/home/paseo/.ssh", "/workspace"]

# No EXPOSE: by default the daemon connects outbound to the Paseo relay.
# If you want direct LAN access, publish 6767 at `docker run`/compose level
# and set PASEO_PASSWORD.

# tini reaps zombies from the agent processes Paseo spawns
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["paseo", "daemon", "start", "--listen", "0.0.0.0:6767"]
