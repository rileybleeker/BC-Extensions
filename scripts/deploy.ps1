# deploy.ps1 - Deploy AL extension to Business Central sandbox
# Usage: .\scripts\deploy.ps1 [-SkipCompile] [-Configuration <name>]

param(
    [switch]$SkipCompile,
    [string]$Configuration = "Microsoft cloud sandbox"
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  BC Extension Deployment" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Read app.json for project info
$appJsonPath = Join-Path $ProjectRoot "app.json"
if (-not (Test-Path $appJsonPath)) {
    Write-Host "ERROR: app.json not found at $appJsonPath" -ForegroundColor Red
    exit 1
}

$appJson = Get-Content $appJsonPath | ConvertFrom-Json
Write-Host "Project: $($appJson.name)" -ForegroundColor White
Write-Host "Version: $($appJson.version)" -ForegroundColor White
Write-Host "Publisher: $($appJson.publisher)" -ForegroundColor White
Write-Host ""

# Check for AL Language extension
$alExtension = code --list-extensions | Where-Object { $_ -eq "ms-dynamics-smb.al" }
if (-not $alExtension) {
    Write-Host "WARNING: AL Language extension not detected" -ForegroundColor Yellow
    Write-Host "Install it from VS Code marketplace: ms-dynamics-smb.al" -ForegroundColor Yellow
}

# Compile the extension
if (-not $SkipCompile) {
    Write-Host "Compiling extension..." -ForegroundColor Yellow

    # Find AL files
    $alFiles = Get-ChildItem -Path (Join-Path $ProjectRoot "src") -Filter "*.al" -Recurse
    Write-Host "Found $($alFiles.Count) AL files" -ForegroundColor Gray

    # Use VS Code task to compile
    # This relies on the AL Language extension
    Push-Location $ProjectRoot
    try {
        # Trigger compilation via VS Code command
        code --command "al.package"

        # Wait for compilation to complete
        Start-Sleep -Seconds 3

        # Check for .app file
        $outputPath = Join-Path $ProjectRoot ".output"
        $appFile = Get-ChildItem -Path $ProjectRoot -Filter "*.app" -ErrorAction SilentlyContinue |
                   Where-Object { $_.DirectoryName -ne (Join-Path $ProjectRoot ".alpackages") } |
                   Sort-Object LastWriteTime -Descending |
                   Select-Object -First 1

        if ($appFile) {
            Write-Host "Compiled: $($appFile.Name)" -ForegroundColor Green
        }
    }
    finally {
        Pop-Location
    }
}

# Deploy using VS Code AL extension
Write-Host ""
Write-Host "Deploying to Business Central..." -ForegroundColor Yellow
Write-Host "Configuration: $Configuration" -ForegroundColor Gray

Push-Location $ProjectRoot
try {
    # Trigger publish via VS Code command
    # This opens BC in browser and deploys
    code --command "al.publishNoDebug"

    Write-Host ""
    Write-Host "Deployment initiated!" -ForegroundColor Green
    Write-Host "Check VS Code output panel for deployment status" -ForegroundColor Gray
    Write-Host "Business Central should open in your browser" -ForegroundColor Gray
}
finally {
    Pop-Location
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Deployment Complete" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
