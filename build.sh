#!/bin/bash
# Timmy 빌드 스크립트: 실행 파일을 만들고 .app 번들로 포장한 뒤 임시 서명한다.
set -euo pipefail
cd "$(dirname "$0")"

APP="Timmy.app"

echo "==> 컴파일 (release)"
swift build -c release

echo "==> .app 번들 생성"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp ".build/release/Timmy" "$APP/Contents/MacOS/Timmy"

if [ -f "Icon/AppIcon.icns" ]; then
    cp "Icon/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
else
    echo "    (Icon/AppIcon.icns 가 없어 아이콘 없이 빌드합니다. make-icon.sh 를 먼저 실행하세요)"
fi

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>          <string>Timmy</string>
    <key>CFBundleIdentifier</key>          <string>com.local.timmy</string>
    <key>CFBundleName</key>                <string>Timmy</string>
    <key>CFBundleDisplayName</key>         <string>Timmy</string>
    <key>CFBundleIconFile</key>            <string>AppIcon</string>
    <key>NSCameraUsageDescription</key>
    <string>자세와 눈 깜빡임을 보고 캐릭터 표정에 반영합니다. 영상은 저장하거나 내보내지 않습니다.</string>
    <key>CFBundlePackageType</key>         <string>APPL</string>
    <key>CFBundleShortVersionString</key>  <string>1.0</string>
    <key>CFBundleVersion</key>             <string>1</string>
    <key>LSMinimumSystemVersion</key>      <string>13.0</string>
    <key>LSUIElement</key>                 <true/>
    <key>NSHighResolutionCapable</key>     <true/>
</dict>
</plist>
PLIST

echo "==> 임시(ad-hoc) 서명"
codesign --force --sign - "$APP"

echo
echo "완료: $(pwd)/$APP"
echo "실행:  open $APP"
