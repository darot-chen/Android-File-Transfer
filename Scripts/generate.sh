#!/bin/sh
# Regenerates AndroidFileTransfer.xcodeproj from project.yml.
# Requires XcodeGen: brew install xcodegen
set -e
cd "$(dirname "$0")/.."
xcodegen generate
