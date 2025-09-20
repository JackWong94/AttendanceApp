# deploy_web.ps1
# Safe Flutter Web GitHub Pages Deployment Script with multiple clients
Write-Host "=== Flutter Web Deploy Script ===" -ForegroundColor Cyan

# ---------------------------
# Configuration
# ---------------------------
$ProjectPath = "C:\Users\User\AndroidStudioProjects\AttendanceApp\attendanceapp"
$RepoName    = "AttendanceApp"
$BranchName  = "gh-pages-new"

# Allowed deployment targets
$targets = @{
    "dev"        = "Development"
    "ckhardware" = "CKHardware"
}

# ---------------------------
# Prompt for target
# ---------------------------
Write-Host "Available deployment targets:" -ForegroundColor Yellow
$targets.Keys | ForEach-Object { Write-Host " - $_" -ForegroundColor Green }

$choice = Read-Host "Enter target name (default = dev)"
if ([string]::IsNullOrWhiteSpace($choice)) { $choice = "dev" }

if (-not $targets.ContainsKey($choice)) {
    Write-Host "❌ Invalid choice. Allowed: $($targets.Keys -join ', ')" -ForegroundColor Red
    exit 1
}

$BaseHref   = "/$RepoName/$choice/"
$TargetName = $targets[$choice]
$Url        = "https://jackwong94.github.io/$RepoName/$choice/"

# ---------------------------
# Confirmation (skip for dev)
# ---------------------------
if ($choice -ne "dev") {
    $confirmation = Read-Host "⚠️ Deploy to $TargetName ($choice)? (yes/no)"
    if ($confirmation -ne "yes") {
        Write-Host "❌ Deployment cancelled." -ForegroundColor Red
        exit 0
    }
}

# ---------------------------
# Move into Flutter project
# ---------------------------
Set-Location $ProjectPath

# ---------------------------
# Build Flutter Web (with retry)
# ---------------------------
Write-Host "Building Flutter web app for $TargetName..." -ForegroundColor Green
flutter build web --base-href $BaseHref
if ($LASTEXITCODE -ne 0) {
    Write-Host "⚠️ First build failed, retrying..." -ForegroundColor Yellow
    flutter build web --base-href $BaseHref
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Flutter web build failed twice. Aborting." -ForegroundColor Red
        exit $LASTEXITCODE
    }
}

# ---------------------------
# Go back to repo root
# ---------------------------
$RepoRoot = (Split-Path $ProjectPath -Parent)
Set-Location $RepoRoot

# ---------------------------
# Checkout/Create gh-pages
# ---------------------------
Write-Host "Switching to branch $BranchName..." -ForegroundColor Green
git fetch origin
git checkout $BranchName 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "⚠️ Branch '$BranchName' not found. Creating orphan branch..." -ForegroundColor Yellow
    git checkout --orphan $BranchName
    git reset --hard
}

# ---------------------------
# Validate Flutter build exists
# ---------------------------
$BuildPath = Join-Path $ProjectPath "build\web"
$IndexFile = Join-Path $BuildPath "index.html"

if (-not (Test-Path $IndexFile)) {
    Write-Host "❌ Flutter build output not found at $IndexFile" -ForegroundColor Red
    Write-Host "👉 Make sure 'flutter build web' completed successfully." -ForegroundColor Yellow
    exit 1
}

# ---------------------------
# Replace ONLY the target folder
# ---------------------------
if (Test-Path $choice) { Remove-Item $choice -Recurse -Force }
New-Item -ItemType Directory -Path $choice | Out-Null
Copy-Item -Path "$BuildPath\*" -Destination $choice -Recurse -Force

# ---------------------------
# Clean up Flutter build cache before git status
# ---------------------------
Write-Host "Cleaning up Flutter build cache (.dart_tool)..." -ForegroundColor Green
if (Test-Path ".dart_tool") { Remove-Item ".dart_tool" -Recurse -Force }

# ---------------------------
# Stage ONLY the target folder
# ---------------------------
git add $choice

# ---------------------------
# Show git status for review
# ---------------------------
git status
Write-Host "`n✅ Staged '$choice'. Review changes above."

# ---------------------------
# Confirm commit & push
# ---------------------------
$proceed = Read-Host "Proceed with commit & push? (yes/no)"
if ($proceed -ne "yes") {
    Write-Host "❌ Deployment aborted after review." -ForegroundColor Red
    exit 0
}

# ---------------------------
# Commit and Push
# ---------------------------
git commit -m "Deploy Flutter web app to $TargetName ($choice)"
git push origin $BranchName

Write-Host "✅ Deployment to $TargetName complete!" -ForegroundColor Cyan
Write-Host "Visit: $Url" -ForegroundColor Yellow
