#!/usr/bin/env bash
set -e

MISE=$(which mise)
eval "$($MISE activate bash)"

npm install
bundle install
rake db:prepare
