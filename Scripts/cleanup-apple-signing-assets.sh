#!/usr/bin/env bash
set -euo pipefail

KEYCHAIN_PATH="$RUNNER_TEMP/bearlock-signing.keychain-db"

if [[ -f "$KEYCHAIN_PATH" ]]; then
  security delete-keychain "$KEYCHAIN_PATH" || true
fi
