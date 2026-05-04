#!/bin/bash
set -euo pipefail

echo "[CI] Post-clone for iOS Boilerplate"
echo "[CI] Build: ${CI_BUILD_NUMBER:-unset} | Branch: ${CI_BRANCH:-unset} | Commit: ${CI_COMMIT:-unset}"

if [ -z "${CI_PRIMARY_REPOSITORY_PATH:-}" ]; then
  echo "[CI][Versioning] ERROR: CI_PRIMARY_REPOSITORY_PATH is not set"
  exit 1
fi

cd "$CI_PRIMARY_REPOSITORY_PATH"

if [ -f "project.yml" ]; then
  if ! command -v xcodegen >/dev/null 2>&1; then
    if command -v brew >/dev/null 2>&1; then
      echo "[CI][Project] XcodeGen missing; installing with Homebrew"
      brew install xcodegen
    else
      echo "[CI][Project] ERROR: project.yml found but xcodegen is not installed and Homebrew is unavailable"
      exit 1
    fi
  fi

  echo "[CI][Project] Generating Xcode project from project.yml"
  xcodegen generate
fi

PBXPROJ=""
if [ -n "${IOS_XCODEPROJ_PATH:-}" ] && [ -f "${CI_PRIMARY_REPOSITORY_PATH}/${IOS_XCODEPROJ_PATH}/project.pbxproj" ]; then
  PBXPROJ="${CI_PRIMARY_REPOSITORY_PATH}/${IOS_XCODEPROJ_PATH}/project.pbxproj"
else
  PBXPROJ=$(find "$CI_PRIMARY_REPOSITORY_PATH" -maxdepth 8 -path "*.xcodeproj/project.pbxproj" | head -1)
fi

if [ -z "$PBXPROJ" ] || [ ! -f "$PBXPROJ" ]; then
  echo "[CI][Versioning] ERROR: could not locate project.pbxproj"
  exit 1
fi

echo "[CI][Versioning] Using project file: $PBXPROJ"

if [ -z "${CI_BUILD_NUMBER:-}" ]; then
  echo "[CI][Versioning] WARNING: CI_BUILD_NUMBER missing; leaving CURRENT_PROJECT_VERSION unchanged"
  exit 0
fi

before_build=$(grep -m1 "CURRENT_PROJECT_VERSION = " "$PBXPROJ" | sed -E 's/.*CURRENT_PROJECT_VERSION = ([^;]+);/\1/' || true)
before_marketing=$(grep -m1 "MARKETING_VERSION = " "$PBXPROJ" | sed -E 's/.*MARKETING_VERSION = ([^;]+);/\1/' || true)

echo "[CI][Versioning] Before: MARKETING_VERSION=${before_marketing:-unknown} CURRENT_PROJECT_VERSION=${before_build:-unknown}"

sed -i '' "s/CURRENT_PROJECT_VERSION = [^;]*/CURRENT_PROJECT_VERSION = ${CI_BUILD_NUMBER}/g" "$PBXPROJ"

after_build=$(grep -m1 "CURRENT_PROJECT_VERSION = " "$PBXPROJ" | sed -E 's/.*CURRENT_PROJECT_VERSION = ([^;]+);/\1/' || true)
if [ "$after_build" != "$CI_BUILD_NUMBER" ]; then
  echo "[CI][Versioning] ERROR: expected CURRENT_PROJECT_VERSION=$CI_BUILD_NUMBER but found $after_build"
  exit 1
fi

echo "[CI][Versioning] Applied: CURRENT_PROJECT_VERSION=${after_build}"
