#!/usr/bin/env bash
set -euo pipefail

KEYCHAIN_PATH="$RUNNER_TEMP/bearlock-signing.keychain-db"
KEYCHAIN_PASSWORD="$(uuidgen)"
PROFILE_DIR="$HOME/Library/MobileDevice/Provisioning Profiles"
P12_PATH="$RUNNER_TEMP/bearlock_distribution.p12"

required_env() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "Missing required environment variable: $name"
    exit 1
  fi
}

required_env APPLE_DISTRIBUTION_CERTIFICATE_P12_BASE64
required_env APPLE_DISTRIBUTION_CERTIFICATE_PASSWORD
required_env BEARLOCK_APPSTORE_PROFILE_APP_BASE64
required_env BEARLOCK_APPSTORE_PROFILE_MONITOR_BASE64
required_env BEARLOCK_APPSTORE_PROFILE_SHIELDCONFIGURATION_BASE64
required_env BEARLOCK_APPSTORE_PROFILE_SHIELDACTION_BASE64

security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"

echo "$APPLE_DISTRIBUTION_CERTIFICATE_P12_BASE64" | base64 -D > "$P12_PATH"
security import "$P12_PATH" \
  -P "$APPLE_DISTRIBUTION_CERTIFICATE_PASSWORD" \
  -A \
  -t cert \
  -f pkcs12 \
  -k "$KEYCHAIN_PATH"
security list-keychain -d user -s "$KEYCHAIN_PATH"
security set-key-partition-list -S apple-tool:,apple: -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"

mkdir -p "$PROFILE_DIR"

install_profile() {
  local secret_value="$1"
  local output="$RUNNER_TEMP/profile.mobileprovision"
  local decoded_plist="$RUNNER_TEMP/profile.plist"
  echo "$secret_value" | base64 -D > "$output"
  local uuid
  security cms -D -i "$output" > "$decoded_plist"
  uuid="$(/usr/libexec/PlistBuddy -c 'Print :UUID' "$decoded_plist")"
  cp "$output" "$PROFILE_DIR/$uuid.mobileprovision"
  echo "Installed provisioning profile $uuid"
}

install_profile "$BEARLOCK_APPSTORE_PROFILE_APP_BASE64"
install_profile "$BEARLOCK_APPSTORE_PROFILE_MONITOR_BASE64"
install_profile "$BEARLOCK_APPSTORE_PROFILE_SHIELDCONFIGURATION_BASE64"
install_profile "$BEARLOCK_APPSTORE_PROFILE_SHIELDACTION_BASE64"

security find-identity -v -p codesigning "$KEYCHAIN_PATH"
