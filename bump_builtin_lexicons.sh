#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

mkdir -p ./tmp
git clone --depth 1 --single-branch https://github.com/bluesky-social/atproto.git ./tmp/atproto
mix atex.lexicons ./tmp/atproto/lexicons/com/atproto/**/*.json
rm -rf ./tmp