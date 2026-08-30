#!/usr/bin/env bash
set -euo pipefail

PROFILE_DIR="$HOME/Library/MobileDevice/Provisioning Profiles"
mkdir -p artifacts

if [[ ! -d "$PROFILE_DIR" ]]; then
  echo "Provisioning profile directory does not exist: $PROFILE_DIR"
  exit 1
fi

for profile in "$PROFILE_DIR"/*.mobileprovision; do
  [[ -e "$profile" ]] || continue
  plist="$RUNNER_TEMP/$(basename "$profile").plist"
  security cms -D -i "$profile" > "$plist"

  name="$(/usr/libexec/PlistBuddy -c 'Print :Name' "$plist" 2>/dev/null || true)"
  uuid="$(/usr/libexec/PlistBuddy -c 'Print :UUID' "$plist" 2>/dev/null || true)"
  app_id="$(/usr/libexec/PlistBuddy -c 'Print :Entitlements:application-identifier' "$plist" 2>/dev/null || true)"
  family_controls="$(/usr/libexec/PlistBuddy -c 'Print :Entitlements:com.apple.developer.family-controls' "$plist" 2>/dev/null || true)"
  app_groups="$(/usr/libexec/PlistBuddy -c 'Print :Entitlements:com.apple.security.application-groups' "$plist" 2>/dev/null || true)"

  {
    echo "Profile: $name"
    echo "UUID: $uuid"
    echo "Application Identifier: $app_id"
    echo "Family Controls Entitlement: ${family_controls:-missing}"
    echo "App Groups Entitlement:"
    if [[ -n "$app_groups" ]]; then
      echo "$app_groups"
    else
      echo "missing"
    fi
    echo "---"
  } | tee -a artifacts/provisioning-profile-summary.log
done
