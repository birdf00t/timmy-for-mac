#!/bin/bash
# 배포용 디스크 이미지(Timmy.dmg)를 만든다. build.sh 를 먼저 실행해 Timmy.app 이 있어야 한다.
set -euo pipefail
cd "$(dirname "$0")"

APP="Timmy.app"
DMG="Timmy.dmg"
VOLUME="Timmy"

if [ ! -d "$APP" ]; then
    echo "$APP 이 없습니다. 먼저 ./build.sh 를 실행하세요." >&2
    exit 1
fi

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

echo "==> 스테이징"
cp -R "$APP" "$STAGE/"
# 창에 응용 프로그램 폴더 바로가기를 같이 넣어 드래그로 설치할 수 있게 한다.
ln -s /Applications "$STAGE/Applications"

echo "==> dmg 생성"
rm -f "$DMG"
hdiutil create \
    -volname "$VOLUME" \
    -srcfolder "$STAGE" \
    -fs HFS+ \
    -format UDZO \
    -ov \
    "$DMG" >/dev/null

echo "==> 서명"
codesign --force --sign - "$DMG"

echo
echo "완료: $(pwd)/$DMG  ($(du -h "$DMG" | cut -f1))"
