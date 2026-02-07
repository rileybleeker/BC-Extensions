# publish.ps1 - Full publish pipeline: compile, test, deploy
# Usage: .\scripts\publish.ps1 [-SkipTests] [-IncrementVersion]

param(
    [switch]$SkipTests,
    [switch]$IncrementVersion,
    [ValidateSet("Major", "Minor", "Build", "Revision")]
    [string]$VersionPart = "Build"
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  BC Extension Publish Pipeline" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Read app.json
$appJsonPath = Join-Path $ProjectRoot "app.json"
$appJson = Get-Content $appJsonPath | ConvertFrom-Json
$currentVersion = $appJson.version

Write-Host "Project: $($appJson.name)" -ForegroundColor White
Write-Host "Current Version: $currentVersion" -ForegroundColor White
Write-Host ""

# Step 1: Increment version if requested
if ($IncrementVersion) {
    Write-Host "[1/4] Incrementing version..." -ForegroundColor Yellow

    $versionParts = $currentVersion.Split('.')
    $major = [int]$versionParts[0]
    $minor = [int]$versionParts[1]
    $build = [int]$versionParts[2]
    $revision = if ($versionParts.Count -gt 3) { [int]$versionParts[3] } else { 0 }

    switch ($VersionPart) {
        "Major" { $major++; $minor = 0; $build = 0; $revision = 0 }
        "Minor" { $minor++; $build = 0; $revision = 0 }
        "Build" { $build++ }
        "Revision" { $revision++ }
    }

    $newVersion = "$major.$minor.$build.$revision"
    $appJson.version = $newVersion
    $appJson | ConvertTo-Json -Depth 10 | Set-Content $appJsonPath -Encoding UTF8

    Write-Host "  Version updated: $currentVersion -> $newVersion" -ForegroundColor Green
    Write-Host ""
}
else {
    Write-Host "[1/4] Version increment skipped" -ForegroundColor Gray
    Write-Host ""
}

# Step 2: Validate AL files
Write-Host "[2/4] Validating AL files..." -ForegroundColor Yellow

$srcPath = Join-Path $ProjectRoot "src"
$alFiles = Get-ChildItem -Path $srcPath -Filter "*.al" -Recurse
$errors = @()

foreach ($file in $alFiles) {
    $content = Get-Content $file.FullName -Raw

    # Basic validation checks
    if ($content -match "table\s+(\d+)") {
        $tableId = [int]$matches[1]
        if ($tableId -lt 50100 -or $tableId -gt 50199) {
            $errors += "Table ID $tableId in $($file.Name) is outside allowed range (50100-50199)"
        }
    }

    if ($content -match "page\s+(\d+)") {
        $pageId = [int]$matches[1]
        if ($pageId -lt 50100 -or $pageId -gt 50199) {
            $errors += "Page ID $pageId in $($file.Name) is outside allowed range (50100-50199)"
        }
    }
}

if ($errors.Count -gt 0) {
    Write-Host "  Validation errors found:" -ForegroundColor Red
    foreach ($error in $errors) {
        Write-Host "    - $error" -ForegroundColor Red
    }
    Write-Host ""
    Write-Host "Fix these errors before publishing." -ForegroundColor Red
    exit 1
}

Write-Host "  Validated $($alFiles.Count) AL files" -ForegroundColor Green
Write-Host ""

# Step 3: Run tests
if (-not $SkipTests) {
    Write-Host "[3/4] Running tests..." -ForegroundColor Yellow

    $testScript = Join-Path $PSScriptRoot "run-tests.ps1"
    if (Test-Path $testScript) {
        & $testScript
    }
    else {
        Write-Host "  Test script not found, skipping" -ForegroundColor Gray
    }
    Write-Host ""
}
else {
    Write-Host "[3/4] Tests skipped" -ForegroundColor Gray
    Write-Host ""
}

# Step 4: Deploy
Write-Host "[4/4] Deploying extension..." -ForegroundColor Yellow

$deployScript = Join-Path $PSScriptRoot "deploy.ps1"
if (Test-Path $deployScript) {
    & $deployScript -SkipCompile:$false
}
else {
    Write-Host "  Deploy script not found" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Publish Pipeline Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Version: $($appJson.version)" -ForegroundColor White
Write-Host "Status: Deployed to Business Central" -ForegroundColor White
Write-Host ""
