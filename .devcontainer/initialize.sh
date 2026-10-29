#!/usr/bin/env bash
# Runs on the host before the containers start, see initializeCommand.
# Writes the .env docker compose reads, so a git worktree gets its own
# containers and can use git inside them.
set -e

cd "$(dirname "$0")/.."
checkout="$(pwd -P)"
name="$(basename "$checkout")"

if [ -f .git ]; then
  # A worktree: its .git file points into the main checkout's .git directory
  project="mensa-$(echo "$name" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9_-\n' '-')"
else
  project="mensa"
fi

cat > .devcontainer/.env <<EOF
COMPOSE_PROJECT_NAME=$project
WORKSPACES_ROOT=$(dirname "$checkout")
GIT_COMMON_DIR=$(cd "$(git rev-parse --git-common-dir)" && pwd -P)
EOF
