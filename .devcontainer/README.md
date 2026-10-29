# Development environments

Every checkout of the repository, the main one and each git worktree, runs in
its own devcontainer on OrbStack, with its own services, volumes and network.
Nothing is shared between environments, so several branches can run their
tests at the same time.

`bin/de` manages them. It's the same in every repository that uses this
setup; what differs per repository lives in `.devcontainer/env.conf` and
`.devcontainer/docker-compose.yml`. Run `bin/de` without arguments for its
usage.

## Kinds

The branch decides the kind (`PERSISTENT_BRANCHES` in `env.conf`):

- **Persistent**, e.g. `main`, `staging` and `develop`. Their data survives
  restarts and `bin/de down`, and `bin/de prune` never touches them.
- **Ephemeral**: any other branch. They start from an empty database, filled
  only from the repository's schema, migrations and seeds, and are removed
  completely when the worktree is done.

An environment is named `<repo>-<branch>` (`ENV_REPO` in `env.conf`, the
branch lowercased with anything but letters, digits and dashes replaced), e.g.
`myapp-fix-login`. That's its Docker Compose project, and every container,
volume and network carries the labels `dev.env.name`, `dev.env.kind`,
`dev.env.branch`, `dev.env.path` and `dev.env.gitdir`. Cleanup selects by
these labels only. Services are reachable from the Mac as
`<service>.<env>.orb.local`, e.g. `postgres.myapp-fix-login.orb.local:5432`;
no host ports are published.

## Commands

| Command | |
| --- | --- |
| `bin/de new <branch>` | Create a worktree next to the main checkout (`<repo>-<branch>`) and start its environment. Existing local or remote branches are checked out, new ones start from the default branch (`--from <ref>` for another) |
| `bin/de up` | Create or start this checkout's environment and prepare its databases. `--rebuild` after changing `.devcontainer/` |
| `bin/de exec <cmd>` | Run a command in it, in the same directory relative to the checkout, e.g. `bin/de exec bin/rails test` |
| `bin/de status` | Name, kind, containers, health and URLs |
| `bin/de code [checkout]` | Open a checkout in VS Code inside its devcontainer, starting the environment first if needed. Takes a branch, environment name or worktree folder. `CODE=cursor` for another editor |
| `bin/de down` | Ephemeral: remove it with its data. Persistent: stop it, keeping the data (`--destroy-persistent` deletes it after typing the name) |
| `bin/de prune` | Remove ephemeral environments whose worktree or branch is gone (`--yes` skips the prompt) |

Every command prints the docker and devcontainer commands it runs. They need
OrbStack and Node on the Mac (for `npx @devcontainers/cli`, unless
`devcontainer` is installed) and Git 2.48 or later.

Handy aliases, from anywhere inside a checkout:

```sh
alias de='"$(git rev-parse --show-toplevel)/bin/de"'
alias vc='"$(git rev-parse --show-toplevel)/bin/de" code'   # vc main
```

## Worktrees and folder layout

Worktrees can live next to the main checkout or anywhere else, e.g.

```
~/code/myapp                     main checkout (main, persistent)
~/code/myapp-develop             worktree (develop, persistent)
~/workspaces/myapp/<name>        other worktrees (ephemeral)
```

Inside the container a checkout is mounted at `/workspaces/<host path>`,
together with the repository's `.git`, and `/workspaces/<repo>` links to it.
Worktrees use relative paths (`git config worktree.useRelativePaths true`,
set by `bin/de up`), so their `.git` link resolves inside the container too.

To make worktrees with plain git:

```sh
bin/de new fix-login     # git worktree add ../myapp-fix-login + bin/de up
cd ../myapp-fix-login
bin/de exec bin/rails test
bin/de code              # open in VS Code
bin/de down && cd - && git worktree remove ../myapp-fix-login
bin/de prune             # catches anything removed without bin/de down
```

`git worktree add` followed by `bin/de up` works the same.

## Local files and secrets

Ignored files listed in `.worktreeinclude`, like `.envrc` and
`mise.local.toml`, are copied (never linked) from the main checkout into new
worktrees by `bin/de up`. Secrets the container needs, such as a package
registry token for `bundle install`, go in `mise.local.toml`:

```toml
[env]
BUNDLE_RUBYGEMS__PKG__GITHUB__COM = "..."
```

## System tests

System tests use the environment's own headless Selenium container
(`SELENIUM_URL` in `env.conf`). To watch a failing test in a browser on the
Mac, start a Selenium there and override it for one command:

```sh
SELENIUM_URL=http://host.docker.internal:4444/ HEADLESS=0 bin/de exec bin/rails test:system
```

## Using it in another repository

From a repository that has the setup:

```sh
bin/de init ~/code/otherapp
```

This copies `bin/de` and this README, which are the same everywhere, and
updates them when run again. The repository specific files (the rest of
`.devcontainer/` and `.worktreeinclude`) are copied only when missing, or
replaced with `--force`. `env.conf` is written for the target repository, and
`.devcontainer/.env` and `mise.local.toml` are added to its `.gitignore`.
Then adapt:

- `env.conf`: `ENV_REPO`, `PERSISTENT_BRANCHES`, `SELENIUM_URL` and
  `UP_COMMAND`.
- `docker-compose.yml`: the services. Keep the `x-env-labels` anchor on every
  service, volume and network, the two `/workspaces` mounts of the `app`
  service, and `restart: ${ENV_RESTART:-no}`.
- `postStart.sh`: how the app installs its dependencies and prepares its
  databases.
