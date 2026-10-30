#!/usr/bin/env bash
set -e

MISE="$HOME/.local/bin/mise"
# Trust first, activating reads mise.local.toml too
"$MISE" trust
eval "$("$MISE" activate bash)"
"$MISE" install
sudo chmod 666 /ssh-agent
# So git over SSH, e.g. a git source in the Gemfile, doesn't stop to ask
mkdir -p ~/.ssh
ssh-keygen -F github.com >/dev/null 2>&1 || ssh-keyscan -t ed25519 github.com 2>/dev/null >> ~/.ssh/known_hosts

"$MISE" exec -- npm install
"$MISE" exec -- bundle install
# From the engine root, so the engine's own migrations are included
"$MISE" exec -- bin/rails app:db:prepare
"$MISE" exec --cd test/dummy -- rake tailwindcss:config
# Propshaft only serves app/assets/builds when it exists at boot
"$MISE" exec --cd test/dummy -- rake tailwindcss:build
