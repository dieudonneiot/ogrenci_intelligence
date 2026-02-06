param(
  [switch]$RebuildDebug
)

$ErrorActionPreference = "Stop"

function Assert-RepoRoot {
  if (-not (Test-Path "pubspec.yaml")) {
    throw "Run this script from the repo root (folder containing pubspec.yaml)."
  }
}

function Remove-IfExists([string]$Path) {
  if (Test-Path $Path) {
    Write-Host "Removing $Path"
    Remove-Item -Force -Recurse $Path
  }
}

Assert-RepoRoot

Write-Host "Repairing Windows Firebase C++ SDK cache (fixes intermittent 'cmake -E tar: ZIP decompression failed (-5)')..."

# The Firebase C++ SDK archive is downloaded into the Windows build directory
# (e.g. build/windows/x64/firebase_cpp_sdk_windows_12.7.0.zip) and extracted
# into build/windows/x64/extracted/firebase_cpp_sdk_windows.
$zips = Get-ChildItem -Recurse -File -ErrorAction SilentlyContinue `
  -Path "build\\windows" `
  -Filter "firebase_cpp_sdk_windows_*.zip"

foreach ($zip in $zips) {
  Remove-IfExists $zip.FullName
}

# Remove extracted SDK folders (all configs/architectures).
$extractedRoots = Get-ChildItem -Recurse -Directory -ErrorAction SilentlyContinue `
  -Path "build\\windows" `
  -Filter "firebase_cpp_sdk_windows"

foreach ($dir in $extractedRoots) {
  Remove-IfExists $dir.FullName
}

# Remove CMake cache to force a clean configure step.
$cmakeCaches = Get-ChildItem -Recurse -File -ErrorAction SilentlyContinue `
  -Path "build\\windows" `
  -Filter "CMakeCache.txt"

foreach ($cache in $cmakeCaches) {
  Remove-IfExists $cache.FullName
}

Write-Host "Done."
Write-Host "Next: flutter clean; flutter pub get; flutter build windows --debug"

if ($RebuildDebug) {
  & flutter clean
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

  & flutter pub get
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

  & flutter build windows --debug
  exit $LASTEXITCODE
}

