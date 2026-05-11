#!/usr/bin/env bash
set -e
MISE=$(which mise)

eval "$($MISE activate bash)"
$MISE trust
$MISE install
sudo chmod 666 /ssh-agent
