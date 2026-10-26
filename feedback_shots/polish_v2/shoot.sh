#!/bin/zsh
# usage: shoot.sh NN_name "ENV=.. ENV=.."
cd ~/mz-preview-all/ManzaiGame
U=E5D11233-FE99-429F-A55C-8B0FA5793568
D=/tmp/mzbuild_v2
xcodebuild -quiet -project ManzaiGame.xcodeproj -scheme ManzaiGame -destination "id=$U" -derivedDataPath $D build 2>&1 | grep -E 'error:' | head -20
APP=$(ls -d $D/Build/Products/Debug-iphonesimulator/*.app | head -1)
BID=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' $APP/Info.plist)
xcrun simctl terminate $U $BID 2>/dev/null
xcrun simctl install $U $APP
OUT=~/manzai-game/feedback_shots/polish_v2/$1.png
envs=""; for kv in ${=2}; do envs="$envs SIMCTL_CHILD_$kv"; done
env SIMCTL_CHILD_MZ_NOCHIP=1 ${=envs} xcrun simctl launch $U $BID >/dev/null
sleep ${3:-4}
xcrun simctl io $U screenshot /tmp/mz_raw.png >/dev/null 2>&1
sips -Z 900 /tmp/mz_raw.png --out $OUT >/dev/null
echo $OUT
