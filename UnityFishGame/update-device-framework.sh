#!/bin/zsh
set -euo pipefail

project_root="${0:A:h}"
unity_editor="${UNITY_EDITOR:-/Applications/Unity/Hub/Editor/6000.6.6f1/Unity.app/Contents/MacOS/Unity}"
developer_dir="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
build_root="${TMPDIR:-/tmp}/chinsekid-unity-device-framework"
export_log="${build_root}/unity-export.log"
build_log="${build_root}/unity-framework.log"

mkdir -p "${build_root}"

"${unity_editor}" -batchmode -nographics -quit \
  -projectPath "${project_root}" \
  -executeMethod Chinsekid.FishGame.Editor.FishGameProjectSetup.ExportIOSXcodeProject \
  -logFile "${export_log}"

DEVELOPER_DIR="${developer_dir}" \
CLANG_MODULE_CACHE_PATH="${build_root}/clang-cache" \
xcodebuild \
  -project "${project_root}/Build/UnityFishGame-iOS/Unity-iPhone.xcodeproj" \
  -scheme UnityFramework \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "${build_root}/DerivedData" \
  CODE_SIGNING_ALLOWED=NO build > "${build_log}" 2>&1 || {
    tail -80 "${build_log}"
    exit 1
  }

framework="${build_root}/DerivedData/Build/Products/Release-iphoneos/UnityFramework.framework"
destination="${project_root}/Build/UnityFishGame.xcframework/ios-arm64/UnityFramework.framework"
if [[ ! -f "${framework}/UnityFramework" ]]; then
  print -u2 "UnityFramework build product is missing: ${framework}"
  exit 1
fi
ditto "${framework}" "${destination}"
print "Updated ${destination}"
print "You can now build chinsekid.xcodeproj on your iPad in Xcode."
