Write-Host "=== Attendance App Script ===" -ForegroundColor Cyan

function gotoAppFolder {
    $ProjectPath = Join-Path $PSScriptRoot "attendanceApp"
    Set-Location $ProjectPath
}

function gotoRootFolder {
    Set-Location $PSScriptRoot
}

# Supported Options
$options = [ordered]@{
    "r"    = "Run Attendance App"
    "d" = "Deploy Attendance App To Github"
}

Write-Host "Script options:" -ForegroundColor Yellow
$options.GetEnumerator() | ForEach-Object {
    Write-Host " - $($_.Key) : $($_.Value)" -ForegroundColor Green
}

$choice = Read-Host "Enter target name (default = run)"

if ([string]::IsNullOrWhiteSpace($choice)) {
    $choice = "run"
}

switch ($choice) {
    "run" {
        Write-Host "Running Attendance App..." -ForegroundColor Green
        gotoAppFolder
        flutter run -d chrome --web-port=5000 --dart-define-from-file=env_DoNotExpose/attendanceApp_firebase_config.json
        gotoRootFolder
    }
    "deploy" {
        Write-Host "Deploying Attendance App..."
        gotoAppFolder
        ./deploy_web.ps1
        gotoRootFolder
    }
    default {
        Write-Host "❌ Not Supported" -ForegroundColor Red
    }
}