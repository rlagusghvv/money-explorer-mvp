#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"

APP_ID="${APP_ID:-com.splui.econadventure}"
TEAM_ID="${TEAM_ID:-FCHA9MNH8C}"
API_KEY_JSON="${OPENCLAW_ASC_API_KEY_JSON:-$HOME/.openclaw/secrets/appstoreconnect/api_key.json}"

if [[ ! -f "$API_KEY_JSON" ]]; then
  echo "Missing API key json: $API_KEY_JSON" >&2
  exit 1
fi

command -v fastlane >/dev/null || { echo "fastlane not found" >&2; exit 1; }

TMP_DIR="$(mktemp -d)"
PROFILE_PATH="$TMP_DIR/appstore.mobileprovision"

fastlane sigh \
  --platform ios \
  --app_identifier "$APP_ID" \
  --api_key_path "$API_KEY_JSON" \
  --output_path "$TMP_DIR" \
  --filename "appstore.mobileprovision" \
  --skip_install true

PROFILE_NAME="$(security cms -D -i "$PROFILE_PATH" | plutil -extract Name raw -o - -)"
PROFILE_UUID="$(security cms -D -i "$PROFILE_PATH" | plutil -extract UUID raw -o - -)"

mkdir -p "$HOME/Library/MobileDevice/Provisioning Profiles"
cp -f "$PROFILE_PATH" "$HOME/Library/MobileDevice/Provisioning Profiles/$PROFILE_UUID.mobileprovision"

EXPORT_PLIST="$TMP_DIR/ExportOptions.plist"
cat > "$EXPORT_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>app-store</string>
  <key>signingStyle</key><string>manual</string>
  <key>teamID</key><string>$TEAM_ID</string>
  <key>signingCertificate</key><string>Apple Distribution</string>
  <key>provisioningProfiles</key>
  <dict><key>$APP_ID</key><string>$PROFILE_NAME</string></dict>
  <key>stripSwiftSymbols</key><true/>
  <key>compileBitcode</key><false/>
</dict>
</plist>
EOF

flutter clean >/dev/null
flutter pub get >/dev/null
flutter build ipa --release --export-options-plist "$EXPORT_PLIST"

IPA_PATH="$(ls -1 "$ROOT_DIR/build/ios/ipa"/*.ipa | head -n 1)"

fastlane pilot upload \
  --api_key_path "$API_KEY_JSON" \
  --ipa "$IPA_PATH" \
  --skip_waiting_for_build_processing true

echo "DONE: uploaded $IPA_PATH"
