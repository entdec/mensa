#!/usr/bin/env bash
set -e

MISE="$HOME/.local/bin/mise"
# Trust first, activating reads mise.local.toml too
"$MISE" trust
eval "$("$MISE" activate bash)"
"$MISE" install
sudo chmod 666 /ssh-agent

"$MISE" exec -- npm install
"$MISE" exec -- bundle install
# From the engine root, so the engine's own migrations are included
"$MISE" exec -- bin/rails app:db:prepare
"$MISE" exec --cd test/dummy -- rake tailwindcss:config
# Propshaft only serves app/assets/builds when it exists at boot
"$MISE" exec --cd test/dummy -- rake tailwindcss:build
