# TestFlight CI Setup

This checklist prepares GitHub Actions to upload Bear Lock builds to TestFlight.
Do not paste private keys, certificate passwords, or provisioning profiles into chat.

## Fixed Identifiers

- Team ID: `3M4M7DRUZY`
- Main app bundle ID: `com.hiyozoo.bearlock`
- Device Activity Monitor extension: `com.hiyozoo.bearlock.monitor`
- Shield Configuration extension: `com.hiyozoo.bearlock.shieldconfiguration`
- Shield Action extension: `com.hiyozoo.bearlock.shieldaction`
- App Group: `group.com.hiyozoo.bearlock`

## Apple Developer Setup

1. Open Apple Developer Account > Certificates, Identifiers & Profiles.
2. Confirm these 4 explicit App IDs exist:
   - `com.hiyozoo.bearlock`
   - `com.hiyozoo.bearlock.monitor`
   - `com.hiyozoo.bearlock.shieldconfiguration`
   - `com.hiyozoo.bearlock.shieldaction`
3. For each App ID, confirm App Groups is enabled and `group.com.hiyozoo.bearlock` is selected.
4. For each App ID, confirm Family Controls Development is enabled.
5. Request Family Controls Distribution for the main app and Screen Time API extensions.
6. Wait until Family Controls Distribution is assigned before creating final App Store provisioning profiles.

## App Store Connect Setup

1. Open App Store Connect > Apps > New App.
2. Create the app record:
   - Name: `Bear Lock`
   - Bundle ID: `com.hiyozoo.bearlock`
   - SKU: `bearlock-ios`
   - Primary language: Japanese or English
3. Open Users and Access > Integrations > App Store Connect API.
4. Create an API key:
   - Name: `BearLock CI`
   - Access: App Manager or higher
5. Download the `.p8` key once and store it safely.
6. Record the Issuer ID and Key ID.

## Distribution Certificate

Create or reuse one Apple Distribution certificate.

If using OpenSSL:

```sh
openssl genrsa -out bearlock_distribution.key 2048
openssl req -new \
  -key bearlock_distribution.key \
  -out bearlock_distribution.certSigningRequest \
  -subj "/emailAddress=APPLE_ID_EMAIL,CN=Bear Lock Distribution,C=JP"
```

Upload `bearlock_distribution.certSigningRequest` when Apple asks for the CSR.
Download the issued `.cer`, then create the `.p12`:

```sh
openssl x509 -inform DER -in distribution.cer -out distribution.pem
openssl pkcs12 -export \
  -inkey bearlock_distribution.key \
  -in distribution.pem \
  -out bearlock_distribution.p12
```

Set a strong export password. Keep both the `.p12` and password available for GitHub Secrets.

## Provisioning Profiles

After Family Controls Distribution is approved, create App Store provisioning profiles:

- `BearLock AppStore App` for `com.hiyozoo.bearlock`
- `BearLock AppStore Monitor` for `com.hiyozoo.bearlock.monitor`
- `BearLock AppStore ShieldConfiguration` for `com.hiyozoo.bearlock.shieldconfiguration`
- `BearLock AppStore ShieldAction` for `com.hiyozoo.bearlock.shieldaction`

Download the 4 `.mobileprovision` files.

If GitHub Actions reports missing Family Controls or App Groups entitlements, check the App ID
capabilities again, then recreate and re-download the provisioning profiles. Existing profiles
do not reliably pick up capability changes made after the profile was generated.

## Convert Files For GitHub Secrets

From the directory containing the downloaded files:

```sh
base64 -w 0 bearlock_distribution.p12 > bearlock_distribution.p12.base64
base64 -w 0 BearLock_AppStore_App.mobileprovision > BearLock_AppStore_App.mobileprovision.base64
base64 -w 0 BearLock_AppStore_Monitor.mobileprovision > BearLock_AppStore_Monitor.mobileprovision.base64
base64 -w 0 BearLock_AppStore_ShieldConfiguration.mobileprovision > BearLock_AppStore_ShieldConfiguration.mobileprovision.base64
base64 -w 0 BearLock_AppStore_ShieldAction.mobileprovision > BearLock_AppStore_ShieldAction.mobileprovision.base64
```

If `base64 -w 0` is unavailable on macOS, use:

```sh
base64 -i bearlock_distribution.p12 | tr -d '\n' > bearlock_distribution.p12.base64
```

Repeat the same pattern for each `.mobileprovision` file.

## Add GitHub Secrets

Open GitHub repository > Settings > Secrets and variables > Actions > New repository secret.

Add these secrets:

- `APP_STORE_CONNECT_ISSUER_ID`: App Store Connect Issuer ID
- `APP_STORE_CONNECT_KEY_ID`: App Store Connect Key ID
- `APP_STORE_CONNECT_API_KEY_P8`: full `.p8` file contents
- `APPLE_DISTRIBUTION_CERTIFICATE_P12_BASE64`: contents of `bearlock_distribution.p12.base64`
- `APPLE_DISTRIBUTION_CERTIFICATE_PASSWORD`: `.p12` export password
- `BEARLOCK_APPSTORE_PROFILE_APP_BASE64`: contents of `BearLock_AppStore_App.mobileprovision.base64`
- `BEARLOCK_APPSTORE_PROFILE_MONITOR_BASE64`: contents of `BearLock_AppStore_Monitor.mobileprovision.base64`
- `BEARLOCK_APPSTORE_PROFILE_SHIELDCONFIGURATION_BASE64`: contents of `BearLock_AppStore_ShieldConfiguration.mobileprovision.base64`
- `BEARLOCK_APPSTORE_PROFILE_SHIELDACTION_BASE64`: contents of `BearLock_AppStore_ShieldAction.mobileprovision.base64`

## Optional GitHub CLI Setup

If `gh` is authenticated and the files are local, secrets can be set with:

```sh
gh secret set APP_STORE_CONNECT_ISSUER_ID --body "ISSUER_ID"
gh secret set APP_STORE_CONNECT_KEY_ID --body "KEY_ID"
gh secret set APP_STORE_CONNECT_API_KEY_P8 < AuthKey_KEYID.p8
gh secret set APPLE_DISTRIBUTION_CERTIFICATE_P12_BASE64 < bearlock_distribution.p12.base64
gh secret set APPLE_DISTRIBUTION_CERTIFICATE_PASSWORD --body "P12_EXPORT_PASSWORD"
gh secret set BEARLOCK_APPSTORE_PROFILE_APP_BASE64 < BearLock_AppStore_App.mobileprovision.base64
gh secret set BEARLOCK_APPSTORE_PROFILE_MONITOR_BASE64 < BearLock_AppStore_Monitor.mobileprovision.base64
gh secret set BEARLOCK_APPSTORE_PROFILE_SHIELDCONFIGURATION_BASE64 < BearLock_AppStore_ShieldConfiguration.mobileprovision.base64
gh secret set BEARLOCK_APPSTORE_PROFILE_SHIELDACTION_BASE64 < BearLock_AppStore_ShieldAction.mobileprovision.base64
```

## Handoff Back To Implementation

After the secrets are set, run the `iOS TestFlight Upload` GitHub Actions workflow manually.
The workflow:

1. Creates a temporary keychain.
2. Imports the Apple Distribution `.p12`.
3. Installs the 4 provisioning profiles.
4. Generates the Xcode project with XcodeGen.
5. Archives `BearLock`.
6. Exports an App Store `.ipa`.
7. Uploads the `.ipa` to App Store Connect/TestFlight with the API key.

The upload workflow uses the `macos-26` GitHub-hosted runner so App Store
Connect validation sees an iOS 26 SDK build.
