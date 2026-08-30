#!/usr/bin/env bash
set -euo pipefail

required_plist_key() {
  local file="$1"
  local key="$2"
  /usr/libexec/PlistBuddy -c "Print :$key" "$file" >/dev/null
}

for file in \
  BearLock/App/Info.plist \
  BearLock/Extensions/DeviceActivityMonitor/Info.plist \
  BearLock/Extensions/ShieldAction/Info.plist \
  BearLock/Extensions/ShieldConfiguration/Info.plist \
  BearLockUITests/Info.plist
do
  plutil -lint "$file" >/dev/null
  required_plist_key "$file" CFBundleExecutable
  required_plist_key "$file" CFBundleIdentifier
  required_plist_key "$file" CFBundlePackageType
  required_plist_key "$file" CFBundleShortVersionString
  required_plist_key "$file" CFBundleVersion
done

required_plist_key BearLock/App/Info.plist UISupportedInterfaceOrientations
required_plist_key BearLock/Extensions/DeviceActivityMonitor/Info.plist CFBundleDisplayName
required_plist_key BearLock/Extensions/ShieldAction/Info.plist CFBundleDisplayName
required_plist_key BearLock/Extensions/ShieldConfiguration/Info.plist CFBundleDisplayName

/usr/libexec/PlistBuddy -c "Print :NSExtension:NSExtensionPointIdentifier" \
  BearLock/Extensions/ShieldAction/Info.plist \
  | grep -q "com.apple.ManagedSettings.shield-action-service"

for file in \
  BearLock/App/BearLock.entitlements \
  BearLock/Extensions/DeviceActivityMonitor/BearLockMonitorExtension.entitlements \
  BearLock/Extensions/ShieldAction/BearLockShieldActionExtension.entitlements \
  BearLock/Extensions/ShieldConfiguration/BearLockShieldConfigurationExtension.entitlements
do
  plutil -lint "$file" >/dev/null
  grep -q "group.com.hiyozoo.bearlock" "$file"
  grep -q "com.apple.developer.family-controls" "$file"
done

while IFS= read -r -d '' file; do
  plutil -lint "$file" >/dev/null
done < <(find BearLock -name '*.strings' -print0)

/usr/libexec/PlistBuddy -c "Print :NSExtension:NSExtensionPointIdentifier" \
  BearLock/Extensions/ShieldConfiguration/Info.plist \
  | grep -q "com.apple.ManagedSettingsUI.shield-configuration-service"

check_image_max_size() {
  local file="$1"
  local max_width="$2"
  local max_height="$3"
  local max_bytes="$4"
  local actual_width
  local actual_height
  local actual_bytes
  actual_width="$(sips -g pixelWidth "$file" | awk '/pixelWidth/ { print $2 }')"
  actual_height="$(sips -g pixelHeight "$file" | awk '/pixelHeight/ { print $2 }')"
  if stat -f '%z' "$file" >/dev/null 2>&1; then
    actual_bytes="$(stat -f '%z' "$file")"
  else
    actual_bytes="$(stat -c '%s' "$file")"
  fi

  if (( actual_width > max_width || actual_height > max_height || actual_bytes > max_bytes )); then
    echo "Image exceeds limit for $file: ${actual_width}x${actual_height}, ${actual_bytes} bytes; max ${max_width}x${max_height}, ${max_bytes} bytes"
    exit 1
  fi
}

check_image_max_size BearLock/Extensions/ShieldConfiguration/Assets.xcassets/ShieldBearVisualLocked.imageset/ShieldBearVisualLocked.png 256 256 102400

echo "iOS project static validation passed"
