# oo - PowerShell entry point for the ConnectOnion agent networking bundle.
#
# 1. Downloads a self-contained CPython into ~/.co/env (no system python
#    required), 2. clones the repo into ~/.connectonion/bundles/oo, then
#    3. hands off to install.py running on the bundled CPython.
#
#   Install:    irm agent.openonion.ai/install.ps1 | iex
#   Uninstall:  & ([scriptblock]::Create((irm agent.openonion.ai/install.ps1))) -Uninstall
#   Local dev:  $env:OO_SOURCE_DIR='C:\path\to\repo'; .\install.ps1

[CmdletBinding()]
param(
  [switch]$Uninstall
)

$ErrorActionPreference = 'Stop'

$Repo     = if ($env:OO_REPO)         { $env:OO_REPO }         else { 'openonion/oo' }
$Branch   = if ($env:OO_BRANCH)       { $env:OO_BRANCH }       else { 'main' }
$Source   = $env:OO_SOURCE_DIR
$CacheDir = Join-Path $HOME '.connectonion\bundles\oo'

$CoEnv    = Join-Path $HOME '.co\env'
$CoPy     = Join-Path $CoEnv 'python\python.exe'

$PbsRelease = if ($env:OO_PBS_RELEASE) { $env:OO_PBS_RELEASE } else { '20241016' }
$PbsPython  = if ($env:OO_PBS_PYTHON)  { $env:OO_PBS_PYTHON }  else { '3.12.7' }

function Write-Fail { param($m) Write-Host $m -ForegroundColor Red; exit 1 }

# ----- prerequisites ------------------------------------------------------
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  Write-Fail 'git is required but not installed. Install Git for Windows first.'
}
if (-not (Get-Command tar -ErrorAction SilentlyContinue)) {
  Write-Fail 'tar is required but not found (ships with Windows 10+).'
}

# ----- ensure self-contained python at ~/.co/env/python -------------------
if (-not (Test-Path $CoPy)) {
  $arch = if ([System.Environment]::Is64BitOperatingSystem) { 'x86_64' } else { Write-Fail '32-bit Windows is not supported.' }
  $triple = "$arch-pc-windows-msvc-shared"
  $asset  = "cpython-$PbsPython+$PbsRelease-$triple-install_only.tar.gz"
  $url    = "https://github.com/astral-sh/python-build-standalone/releases/download/$PbsRelease/$asset"

  Write-Host "Downloading Python $PbsPython -> $CoEnv..."
  $null = New-Item -ItemType Directory -Force -Path $CoEnv
  $tarball = Join-Path $CoEnv $asset
  Invoke-WebRequest -Uri $url -OutFile $tarball -UseBasicParsing
  # tarball contains a top-level "python\" directory.
  # GNU tar from Git Bash on PATH parses the "C:" as a remote host; pin to Windows' bsdtar.
  $tarExe = Join-Path $env:SystemRoot 'System32\tar.exe'
  if (-not (Test-Path $tarExe)) { $tarExe = 'tar' }
  & $tarExe -xzf $tarball -C $CoEnv
  Remove-Item -Force $tarball
  if (-not (Test-Path $CoPy)) { Write-Fail "python bootstrap failed: $CoPy not found after extract" }
}

# ----- fetch the bundle ---------------------------------------------------
$null = New-Item -ItemType Directory -Force -Path (Split-Path $CacheDir)

if ($Source) {
  if (-not (Test-Path $Source)) { Write-Fail "OO_SOURCE_DIR=$Source not found" }
  Write-Host "Installing from local path $Source..."
  if (Test-Path $CacheDir) { Remove-Item -Recurse -Force $CacheDir }
  $null = New-Item -ItemType Directory -Force -Path $CacheDir
  Copy-Item -Recurse -Force "$Source\*" $CacheDir
} else {
  if (Test-Path (Join-Path $CacheDir '.git')) {
    Write-Host "Updating $Repo..."
    git -C $CacheDir fetch --quiet --depth 1 origin $Branch | Out-Null
    git -C $CacheDir reset --quiet --hard "origin/$Branch" | Out-Null
  } else {
    Write-Host "Installing $Repo..."
    if (Test-Path $CacheDir) { Remove-Item -Recurse -Force $CacheDir }
    git clone --quiet --depth 1 --branch $Branch "https://github.com/$Repo.git" $CacheDir | Out-Null
  }
}

# ----- hand off to install.py --------------------------------------------
$installPy = Join-Path $CacheDir 'install.py'
if (-not (Test-Path $installPy)) { Write-Fail "install.py missing from $CacheDir" }

$pyArgs = @($installPy)
if ($Uninstall) { $pyArgs += '--uninstall' }

& $CoPy @pyArgs
exit $LASTEXITCODE
