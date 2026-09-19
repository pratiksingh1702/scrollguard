#!/usr/bin/env bash
set -e

echo "==> Running dart format check..."
dart format --output=none --set-exit-if-changed .

echo "==> Running flutter analyze..."
flutter analyze

echo "==> Running flutter test..."
flutter test

echo "==> All pre-commit checks passed!"
