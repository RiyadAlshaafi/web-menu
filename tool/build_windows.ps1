#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$envFile = Join-Path $root ".env"
if (-not (Test-Path $envFile)) {
  Write-Error "Missing .env in $root. Copy .env.example to .env and add SUPABASE_URL and SUPABASE_ANON_KEY."
}

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  Write-Error "flutter is not on PATH."
}

flutter pub get
flutter build windows --release --dart-define-from-file=.env

Write-Host "Windows build finished. Exe:"
Write-Host "  $root\build\windows\x64\runner\Release\menu_web_v1.exe"
