$ErrorActionPreference = "Stop"

Write-Host "==> Running dart format check..."
dart format --output=none --set-exit-if-changed .

Write-Host "==> Running flutter analyze..."
flutter analyze

Write-Host "==> Running flutter test..."
flutter test

Write-Host "==> All pre-commit checks passed!"
