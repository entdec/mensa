#!/usr/bin/env bash
set -e

MISE="$HOME/.local/bin/mise"
eval "$("$MISE" activate bash)"
"$MISE" trust
"$MISE" install
sudo chmod 666 /ssh-agent

"$MISE" exec -- npm install
"$MISE" exec -- bundle install
"$MISE" exec --cd test/dummy -- rake db:prepare
"$MISE" exec --cd test/dummy -- rake tailwindcss:config
# Propshaft only serves app/assets/builds when it exists at boot
"$MISE" exec --cd test/dummy -- rake tailwindcss:build
