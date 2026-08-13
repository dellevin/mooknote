@echo off
rem MookNote 一键打包：按 ABI 拆分，产出各架构独立的小 APK
rem 侧载时选择 arm64-v8a 版本（现代手机均支持）
flutter build apk --release --split-per-abi
echo.
echo ===== APK 产物 =====
dir /b build\app\outputs\flutter-apk\*release.apk 2>nul