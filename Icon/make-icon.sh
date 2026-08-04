#!/bin/bash
# icon.png 에서 앱 아이콘(AppIcon.icns)을 만든다.
# icon.png 를 바꿨으면 이 스크립트를 다시 돌린 뒤 ../build.sh 를 실행하면 된다.
set -euo pipefail
cd "$(dirname "$0")"

if [ ! -f icon.png ]; then
    echo "icon.png 가 없습니다. 배경이 투명한 PNG 를 이 폴더에 넣어 주세요." >&2
    exit 1
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "==> 변환기 컴파일"
swiftc -O main.swift -o "$WORK/iconrender"

echo "==> PNG 렌더링"
rm -rf AppIcon.iconset
mkdir -p AppIcon.iconset
"$WORK/iconrender" icon.png AppIcon.iconset

echo "==> icns 변환"
iconutil -c icns AppIcon.iconset -o AppIcon.icns

echo
echo "완료: $(pwd)/AppIcon.icns"
