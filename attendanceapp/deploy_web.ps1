Write-Host "=== Flutter Web Deploy Script ===" -ForegroundColor Cyan

# ---------------------------
# Allowed deployment targets
# ---------------------------
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
if ([string]::IsNullOrWhiteSpace($choice)) {
    $choice = "dev"
}

if (-not $targets.ContainsKey($choice)) {
    Write-Host "❌ Invalid choice. Allowed: $($targets.Keys -join ', ')" -ForegroundColor Red
    exit 1
}

$RepoName   = "AttendanceApp"
$BranchName = "gh-pages"
$BaseHref   = "/$choice/"
$TargetName = $targets[$choice]
$Url        = "https://jackwong94.github.io/$RepoName/$choice/"

# ---------------------------
# Fast clean: remove only flutter_build cache
# ---------------------------
if (Test-Path ".dart_tool/flutter_build") {
    Write-Host "🧹 Clearing incremental build cache (.dart_tool/flutter_build)..." -ForegroundColor Yellow
    Remove-Item ".dart_tool/flutter_build" -Recurse -Force
}

# ---------------------------
# Confirmation
# ---------------------------
if ($choice -eq "dev") {
    Write-Host "⚡ Skipping confirmation for dev build." -ForegroundColor DarkGray
} else {
    $confirmation = Read-Host "⚠️ Deploy to $TargetName ($choice)? (yes/no)"
    if ($confirmation -ne "yes") {
        Write-Host "❌ Deployment cancelled." -ForegroundColor Red
        exit 0
    }
}

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
# Checkout gh-pages branch
# ---------------------------
Write-Host "Switching to branch $BranchName..." -ForegroundColor Green
git fetch origin
git checkout $BranchName 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to checkout $BranchName." -ForegroundColor Red
    Write-Host "👉 Possible reasons:" -ForegroundColor Yellow
    Write-Host "   - Branch '$BranchName' does not exist" -ForegroundColor Yellow
    Write-Host "   - You have uncommitted changes (stash or commit first)" -ForegroundColor Yellow
    exit 1
}

# ---------------------------
# Replace only the target folder
# ---------------------------
if (Test-Path $choice) {
    Remove-Item $choice -Recurse -Force
}
New-Item -ItemType Directory -Path $choice | Out-Null

Copy-Item -Path "build\web\*" -Destination $choice -Recurse -Force

# ---------------------------
# Show git status BEFORE add
# ---------------------------
git status

$proceed = "yes"
if ($choice -ne "dev") {
    $proceed = Read-Host "Proceed with commit & push? (yes/no)"
}
if ($proceed -ne "yes") {
    Write-Host "❌ Deployment aborted after git status check." -ForegroundColor Red
    git checkout main
    exit 0
}

# ---------------------------
# Commit and Push
# ---------------------------
git add $choice
git commit -m "🚀 Deploy Flutter web app to $TargetName ($choice)"
git push origin $BranchName

# ---------------------------
# Switch back to main
# ---------------------------
git checkout main

Write-Host "✅ Deployment to $TargetName complete!" -ForegroundColor Cyan
Write-Host "Visit: $Url" -ForegroundColor Yellow
