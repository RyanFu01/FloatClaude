#!/bin/zsh
# Builds FloatClaude.app (Apple silicon) and installs it to ~/Applications.
# Requires the Xcode Command Line Tools: xcode-select --install
set -e
cd "$(dirname "$0")"

APP=build/FloatClaude.app
rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" build/tmp

# Some Command Line Tools releases ship a stale usr/include/swift/module.modulemap
# that redefines SwiftBridging and breaks every build. Shadow it with an empty
# file via a VFS overlay instead of touching system files.
: > build/tmp/empty.modulemap
cat > build/tmp/overlay.yaml <<EOF
{ "version": 0, "case-sensitive": "false", "roots": [ { "type": "file",
  "name": "/Library/Developer/CommandLineTools/usr/include/swift/module.modulemap",
  "external-contents": "$PWD/build/tmp/empty.modulemap" } ] }
EOF

swiftc -O -target arm64-apple-macos13.0 Sources/*.swift \
  -o "$APP/Contents/MacOS/FloatClaude" \
  -framework Cocoa -framework WebKit -framework Carbon \
  -vfsoverlay build/tmp/overlay.yaml -Xcc -ivfsoverlay -Xcc build/tmp/overlay.yaml

# Page scripts and styles injected into claude.ai.
cp Web/* "$APP/Contents/Resources/"

cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>FloatClaude</string>
  <key>CFBundleIdentifier</key><string>local.floatclaude</string>
  <key>CFBundleExecutable</key><string>FloatClaude</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>LSUIElement</key><true/>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>NSHighResolutionCapable</key><true/>
</dict></plist>
EOF

# Ad-hoc signature (not notarized).
codesign --force --sign - "$APP"

mkdir -p ~/Applications
rm -rf ~/Applications/FloatClaude.app
cp -R "$APP" ~/Applications/
echo "Installed to ~/Applications/FloatClaude.app"
