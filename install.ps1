# oo - one-line installer for the ConnectOnion agent networking skill (Windows)
# https://github.com/openonion/oo
#
#   Install:    irm openonion.ai/install.ps1 | iex
#   Update:     re-run the same command
#   Uninstall:  & ([scriptblock]::Create((irm openonion.ai/install.ps1))) -Uninstall
#
# Clones github.com/openonion/oo and copies each platform's files into the
# right location under $HOME for Claude Code, Codex CLI, Cursor, and Kiro.
# Uses copies (not symlinks) so the script never requires admin / Developer Mode.

[CmdletBinding()]
param(
  [switch]$Uninstall
)

$ErrorActionPreference = 'Stop'

$Repo     = if ($env:OO_REPO)      { $env:OO_REPO }      else { 'openonion/oo' }
$Branch   = if ($env:OO_BRANCH)    { $env:OO_BRANCH }    else { 'main' }
$Source   = $env:OO_SOURCE_DIR
$CacheDir = Join-Path $HOME '.oo\cache'

# Each entry: Label | repo-relative source | HOME-relative destination
$Targets = @(
  @{ Label = 'Claude Code'; Src = 'skills\oo';            Dst = '.claude\skills\oo' }
  @{ Label = 'Codex CLI';   Src = 'codex\oo';             Dst = '.codex\skills\oo' }
  @{ Label = 'Cursor';      Src = 'cursor\rules\oo.mdc';  Dst = '.cursor\rules\oo.mdc' }
  @{ Label = 'Kiro';        Src = 'kiro\steering\oo.md';  Dst = '.kiro\steering\oo.md' }
)

function Write-Ok    { param($m) Write-Host "  $([char]0x2713) $m" -ForegroundColor Green }
function Write-Skip  { param($m) Write-Host "  - $m" -ForegroundColor DarkGray }
function Write-Done  { param($m) Write-Host "$([char]0x2713) $m" -ForegroundColor Green }
function Write-Fail  { param($m) Write-Host $m -ForegroundColor Red; exit 1 }

if ($Uninstall) {
  Write-Host 'Uninstalling oo...'
  foreach ($t in $Targets) {
    $full = Join-Path $HOME $t.Dst
    if (Test-Path $full) {
      Remove-Item -Recurse -Force $full
      Write-Ok "removed $($t.Label)  ($full)"
    }
  }
  if (Test-Path $CacheDir) { Remove-Item -Recurse -Force $CacheDir }
  Write-Done 'Uninstalled'
  return
}

# ----- fetch the repo ------------------------------------------------------
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

# ----- copy into every supported agent ------------------------------------
Write-Host ''
Write-Host 'Linking into supported coding agents:'
foreach ($t in $Targets) {
  $srcPath = Join-Path $CacheDir $t.Src
  $dstPath = Join-Path $HOME    $t.Dst

  if (-not (Test-Path $srcPath)) {
    Write-Skip "$($t.Label) - source $($t.Src) missing in repo"
    continue
  }

  $dstParent = Split-Path $dstPath
  if (-not (Test-Path $dstParent)) {
    $null = New-Item -ItemType Directory -Force -Path $dstParent
  }
  if (Test-Path $dstPath) { Remove-Item -Recurse -Force $dstPath }

  if ((Get-Item $srcPath).PSIsContainer) {
    Copy-Item -Recurse -Force $srcPath $dstPath
  } else {
    Copy-Item -Force $srcPath $dstPath
  }
  Write-Ok "$($t.Label)  ->  ~\$($t.Dst)"
}

Write-Host ''
Write-Done 'Done. The /oo command is ready in every linked agent.'
Write-Host ''
Write-Host 'Try in Claude Code:'
Write-Host '  /oo 0x<address> <task>'
