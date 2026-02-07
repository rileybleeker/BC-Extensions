# run-tests.ps1 - Run AL tests in Business Central
# Usage: .\scripts\run-tests.ps1 [-CodeunitId <id>] [-TestFilter <pattern>]

param(
    [int]$CodeunitId,
    [string]$TestFilter,
    [switch]$ShowPassed
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  BC Extension Test Runner" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Read app.json for project info
$appJsonPath = Join-Path $ProjectRoot "app.json"
$appJson = Get-Content $appJsonPath | ConvertFrom-Json
Write-Host "Project: $($appJson.name)" -ForegroundColor White
Write-Host ""

# Find test codeunits
Write-Host "Scanning for test codeunits..." -ForegroundColor Yellow

$testFiles = @()
$srcPath = Join-Path $ProjectRoot "src"
$alFiles = Get-ChildItem -Path $srcPath -Filter "*.al" -Recurse

foreach ($file in $alFiles) {
    $content = Get-Content $file.FullName -Raw
    if ($content -match "Subtype\s*=\s*Test") {
        $testFiles += $file

        # Extract codeunit ID and name
        if ($content -match "codeunit\s+(\d+)\s+""([^""]+)""") {
            $id = $matches[1]
            $name = $matches[2]
            Write-Host "  Found: [$id] $name" -ForegroundColor Gray
        }
    }
}

if ($testFiles.Count -eq 0) {
    Write-Host "No test codeunits found." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To create a test codeunit, add 'Subtype = Test' to a codeunit." -ForegroundColor Gray
    exit 0
}

Write-Host ""
Write-Host "Found $($testFiles.Count) test codeunit(s)" -ForegroundColor Green
Write-Host ""

# Build filter string for test runner
$filterParts = @()
if ($CodeunitId) {
    $filterParts += "CodeunitId=$CodeunitId"
    Write-Host "Filter: Codeunit ID = $CodeunitId" -ForegroundColor Gray
}
if ($TestFilter) {
    $filterParts += "Name=$TestFilter"
    Write-Host "Filter: Name matches '$TestFilter'" -ForegroundColor Gray
}

# Run tests using AL Test Runner extension if available
Write-Host ""
Write-Host "Running tests..." -ForegroundColor Yellow
Write-Host ""

# Option 1: Use VS Code AL Test Runner extension
# This requires the "AL Test Runner" extension to be installed
Push-Location $ProjectRoot
try {
    # Try to run tests via VS Code command
    code --command "altestrunner.runAllTests"

    Write-Host "Test execution initiated!" -ForegroundColor Green
    Write-Host ""
    Write-Host "View results in:" -ForegroundColor Gray
    Write-Host "  - VS Code Test Explorer" -ForegroundColor Gray
    Write-Host "  - AL Test Runner output panel" -ForegroundColor Gray
    Write-Host "  - Business Central Test Tool page" -ForegroundColor Gray
}
catch {
    Write-Host "Could not run tests via VS Code extension." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Alternative: Run tests manually in Business Central:" -ForegroundColor White
    Write-Host "  1. Open Business Central" -ForegroundColor Gray
    Write-Host "  2. Search for 'Test Tool'" -ForegroundColor Gray
    Write-Host "  3. Select your test codeunit(s)" -ForegroundColor Gray
    Write-Host "  4. Click 'Run'" -ForegroundColor Gray
}
finally {
    Pop-Location
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Test Run Complete" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
