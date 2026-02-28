# Library Management System - PowerShell Build Script
# Run this script with: powershell -ExecutionPolicy Bypass -File Build.ps1

param(
    [switch]$Clean,
    [switch]$Test,
    [switch]$Release,
    [switch]$Installer
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "  Library Management System - Build Script" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""

# Navigate to project root
Set-Location $ProjectRoot

# Clean build
if ($Clean) {
    Write-Host "Cleaning build directories..." -ForegroundColor Yellow
    
    if (Test-Path "flutter_app/build") {
        Remove-Item -Recurse -Force "flutter_app/build"
    }
    
    Write-Host "Clean complete." -ForegroundColor Green
}

# Test
if ($Test) {
    Write-Host "Running backend tests..." -ForegroundColor Yellow
    Set-Location backend
    npm test
    Set-Location $ProjectRoot
    
    Write-Host "Running Flutter tests..." -ForegroundColor Yellow
    Set-Location flutter_app
    flutter test
    Set-Location $ProjectRoot
    
    Write-Host "Tests complete." -ForegroundColor Green
}

# Release build
if ($Release -or $Installer) {
    Write-Host "Building Flutter Windows release..." -ForegroundColor Yellow
    Set-Location flutter_app
    
    flutter pub get
    flutter build windows --release
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Flutter build failed!" -ForegroundColor Red
        exit 1
    }
    
    Set-Location $ProjectRoot
    
    Write-Host "Installing backend dependencies..." -ForegroundColor Yellow
    Set-Location backend
    npm install --production
    Set-Location $ProjectRoot
    
    Write-Host "Release build complete." -ForegroundColor Green
}

# Create installer
if ($Installer) {
    Write-Host "Creating installer..." -ForegroundColor Yellow
    
    # Find Inno Setup Compiler
    $iscc = $null
    if (Get-Command iscc -ErrorAction SilentlyContinue) {
        $iscc = "iscc"
    } elseif (Test-Path "C:\Program Files (x86)\Inno Setup 6\ISCC.exe") {
        $iscc = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
    } elseif (Test-Path "C:\Program Files\Inno Setup 6\ISCC.exe") {
        $iscc = "C:\Program Files\Inno Setup 6\ISCC.exe"
    }
    
    if (-not $iscc) {
        Write-Host "ERROR: Inno Setup Compiler not found!" -ForegroundColor Red
        Write-Host "Please install Inno Setup 6 from: https://jrsoftware.org/isdl.php"
        exit 1
    }
    
    & $iscc installer.iss
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Installer creation failed!" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "Installer created in: installer_output/" -ForegroundColor Green
    Get-ChildItem installer_output/*.exe | ForEach-Object { Write-Host "  $($_.Name)" }
}

Write-Host ""
Write-Host "Build script completed." -ForegroundColor Cyan
