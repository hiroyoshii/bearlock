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

python3 - <<'PY'
import json
from pathlib import Path

for path in Path("BearLock").glob("**/*.xcassets/**/Contents.json"):
    with path.open() as handle:
        json.load(handle)
print("asset catalog json ok")
PY

check_image_size() {
  local file="$1"
  local width="$2"
  local height="$3"
  local actual_width
  local actual_height
  actual_width="$(sips -g pixelWidth "$file" | awk '/pixelWidth/ { print $2 }')"
  actual_height="$(sips -g pixelHeight "$file" | awk '/pixelHeight/ { print $2 }')"

  if [[ "$actual_width" != "$width" || "$actual_height" != "$height" ]]; then
    echo "Unexpected image size for $file: ${actual_width}x${actual_height}, expected ${width}x${height}"
    exit 1
  fi
}

check_image_size BearLock/App/Assets.xcassets/AppIcon.appiconset/iphone-20@2x.png 40 40
check_image_size BearLock/App/Assets.xcassets/AppIcon.appiconset/iphone-20@3x.png 60 60
check_image_size BearLock/App/Assets.xcassets/AppIcon.appiconset/iphone-29@2x.png 58 58
check_image_size BearLock/App/Assets.xcassets/AppIcon.appiconset/iphone-29@3x.png 87 87
check_image_size BearLock/App/Assets.xcassets/AppIcon.appiconset/iphone-40@2x.png 80 80
check_image_size BearLock/App/Assets.xcassets/AppIcon.appiconset/iphone-40@3x.png 120 120
check_image_size BearLock/App/Assets.xcassets/AppIcon.appiconset/iphone-60@2x.png 120 120
check_image_size BearLock/App/Assets.xcassets/AppIcon.appiconset/iphone-60@3x.png 180 180
check_image_size BearLock/App/Assets.xcassets/AppIcon.appiconset/ipad-20@1x.png 20 20
check_image_size BearLock/App/Assets.xcassets/AppIcon.appiconset/ipad-20@2x.png 40 40
check_image_size BearLock/App/Assets.xcassets/AppIcon.appiconset/ipad-29@1x.png 29 29
check_image_size BearLock/App/Assets.xcassets/AppIcon.appiconset/ipad-29@2x.png 58 58
check_image_size BearLock/App/Assets.xcassets/AppIcon.appiconset/ipad-40@1x.png 40 40
check_image_size BearLock/App/Assets.xcassets/AppIcon.appiconset/ipad-40@2x.png 80 80
check_image_size BearLock/App/Assets.xcassets/AppIcon.appiconset/ipad-76@1x.png 76 76
check_image_size BearLock/App/Assets.xcassets/AppIcon.appiconset/ipad-76@2x.png 152 152
check_image_size BearLock/App/Assets.xcassets/AppIcon.appiconset/ipad-83_5@2x.png 167 167
check_image_size BearLock/App/Assets.xcassets/AppIcon.appiconset/ios-marketing-1024.png 1024 1024
check_image_size BearLock/App/Assets.xcassets/BrandHero.imageset/BrandHero.png 1672 941
check_image_size BearLock/App/Assets.xcassets/BrandDen.imageset/BrandDen.png 1254 1254
check_image_size BearLock/App/Assets.xcassets/BrandBear.imageset/BrandBear.png 1254 1254
check_image_size BearLock/App/Assets.xcassets/BrandAppIcon.imageset/BrandAppIcon.png 1254 1254
check_image_size BearLock/App/Assets.xcassets/BearVisualReady.imageset/BearVisualReady.png 1448 1086
check_image_size BearLock/App/Assets.xcassets/BearVisualArming.imageset/BearVisualArming.png 1448 1086
check_image_size BearLock/App/Assets.xcassets/BearVisualLocked.imageset/BearVisualLocked.png 1448 1086
check_image_size BearLock/App/Assets.xcassets/BearVisualSleeping.imageset/BearVisualSleeping.png 1448 1086
check_image_size BearLock/Extensions/ShieldConfiguration/Assets.xcassets/ShieldBrandDen.imageset/ShieldBrandDen.png 1254 1254
check_image_size BearLock/Extensions/ShieldConfiguration/Assets.xcassets/ShieldBearVisualLocked.imageset/ShieldBearVisualLocked.png 1448 1086

echo "iOS project static validation passed"
