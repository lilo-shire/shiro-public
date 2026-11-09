#!/bin/zsh
set -eu
source_dir="${0:A:h}"
project_dir="${source_dir:h:h}"
output_dir="${SHIRO_OUTPUT_DIR:-$project_dir/outputs}"
app_dir="$output_dir/Широ.app"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
architecture="${SHIRO_ARCH:-$(uname -m)}"
clang -arch "$architecture" -fobjc-arc -Wall -Wextra -Wno-unused-parameter -mmacosx-version-min=12.0 \
  -framework Cocoa -framework QuartzCore -framework CoreText -framework UserNotifications -framework UniformTypeIdentifiers -framework AVFoundation \
  "$source_dir/main.m" "$source_dir/TimerModel.m" "$source_dir/TaskModel.m" "$source_dir/MixUI.m" "$source_dir/LinkedFile.m" "$source_dir/ShiroRig.m" \
  -o "$app_dir/Contents/MacOS/ShiroPomodoro"
cp "$source_dir/Info.plist" "$app_dir/Contents/Info.plist"
cp "$project_dir/assets/macos/Shiro.icns" "$app_dir/Contents/Resources/"
cp -R "$project_dir/work/shiro-ui-assets/animations" "$app_dir/Contents/Resources/"
cp "$project_dir"/work/shiro-ui-assets/fonts/*.ttf "$project_dir"/work/shiro-ui-assets/fonts/OFL-*.txt "$app_dir/Contents/Resources/"
cp "$project_dir"/work/shiro-ui-assets/sounds/*.wav "$project_dir"/work/shiro-ui-assets/sounds/*.caf "$project_dir"/work/shiro-ui-assets/sounds/CREDITS.txt "$app_dir/Contents/Resources/"
codesign --force --sign - "$app_dir"
codesign --verify --deep --strict "$app_dir"
echo "$app_dir"
