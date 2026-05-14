# oo - PowerShell entry point for the ConnectOnion agent networking bundle.
#
# Thin shim: clones the repo into ~/.connectonion/bundles/oo and hands off
# to install.py, which is the canonical installer. All install logic lives
# in install.py so the PowerShell, shell, and python entry points stay in sync.
#
#   Install:    irm agent.openonion.ai/install.ps1 | iex
#   Uninstall:  & ([scriptblock]::Create((irm agent.openonion.ai/install.ps1))) -Uninstall
#   Local dev:  $env:OO_SOURCE_DIR='C:\path\to\repo'; .\install.ps1

[CmdletBinding()]
param(
  [switch]$Uninstall
)

$ErrorActionPreference = 'Stop'

$Repo     = if ($env:OO_REPO)   { $env:OO_REPO }   else { 'openonion/oo' }
$Branch   = if ($env:OO_BRANCH) { $env:OO_BRANCH } else { 'main' }
$Source   = $env:OO_SOURCE_DIR
$CacheDir = Join-Path $HOME '.connectonion\bundles\oo'

function Write-Fail { param($m) Write-Host $m -ForegroundColor Red; exit 1 }

# ----- locate python ------------------------------------------------------
$py = $null
foreach ($cmd in 'python3', 'python', 'py') {
  if (Get-Command $cmd -ErrorAction SilentlyContinue) { $py = $cmd; break }
}
if (-not $py) { Write-Fail 'python3 is required but not installed.' }

# ----- fetch the repo -----------------------------------------------------
$null = New-Item -ItemType Directory -Force -Path (Split-Path $CacheDir)

if ($Source) {
  if (-not (Test-Path $Source)) { Write-Fail "OO_SOURCE_DIR=$Source not found" }
  Write-Host "Installing from local path $Source..."
  if (Test-Path $CacheDir) { Remove-Item -Recurse -Force $CacheDir }
  $null = New-Item -ItemType Directory -Force -Path $CacheDir
  Copy-Item -Recurse -Force "$Source\*" $CacheDir
} else {
  if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Fail 'git is required but not installed. Install Git for Windows first.'
  }
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

& $py @pyArgs
exit $LASTEXITCODE
