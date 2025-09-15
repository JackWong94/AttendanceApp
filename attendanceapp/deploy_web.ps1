# deploy_web.ps1
# Usage: Run from the root of your Flutter project

# ---------------------------
# Configuration
# ---------------------------
$RepoName = "AttendanceApp"           # Name of your GitHub repo
$BranchName = "gh-pages"             # GitHub Pages branch
$TempPath = "$env:TEMP\AttendanceAppWeb"  # Temporary folder for web build
$BaseHref = "/$RepoName/"            # Base href for Flutter web build

Write-Host "=== Flutter Web Deploy Script ===" -ForegroundColor Cyan

git branch -D $BranchName

# Step 1: Build Flutter web app
Write-Host "Building Flutter web app..." -ForegroundColor Green
flutter build web --base-href $BaseHref

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Flutter web build failed. Aborting deployment. Please try rerun the script" -ForegroundColor Red
    exit $LASTEXITCODE
}

# 🔹 Step 1.5: Ensure face-api models are copied
if (Test-Path ".\web\models") {
    Write-Host "Copying models folder into build/web..." -ForegroundColor Green
    Copy-Item -Path ".\web\models" -Destination ".\build\web\" -Recurse -Force
}

# Step 2: Save changes if any
Write-Host "Stashing uncommitted changes..." -ForegroundColor Green
git stash

# Step 3: Switch or create gh-pages branch
Write-Host "Creating orphan branch '$BranchName'..." -ForegroundColor Green
git checkout --orphan $BranchName
if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to create orphan branch '$BranchName'. Exiting script." -ForegroundColor Red
    exit 1
}

# Step 4: Backup web build (will only run if branch checkout succeeded)
Write-Host "Backing up web build to temporary folder..." -ForegroundColor Green
if (Test-Path $TempPath) { Remove-Item $TempPath -Recurse -Force }
New-Item -ItemType Directory -Path $TempPath -Force
Copy-Item -Path ".\build\web\*" -Destination $TempPath -Recurse

cd ..

# Step 5: Clear old files in gh-pages
Write-Host "Clearing old files in '$BranchName' branch..." -ForegroundColor Green
git rm -rf *

# Step 6: Copy web build directly to ROOT of gh-pages
Write-Host "Copying new web build to '$BranchName' ROOT..." -ForegroundColor Green
Get-ChildItem -Path $TempPath | ForEach-Object {
    Copy-Item -Path $_.FullName -Destination "." -Recurse
}

# Step 7: Delete temporary folder
Write-Host "Deleting temporary folder..." -ForegroundColor Green
Remove-Item -Path $TempPath -Recurse -Force

git status

# Step 8: Commit and push to GitHub
Write-Host "Committing and pushing to '$BranchName'..." -ForegroundColor Green
git add .
git commit -m "Deploy Flutter web app"
git push origin $BranchName --force

git stash
git switch main -f
git clean -f

cd attendanceapp

Write-Host "✅ Deployment complete!" -ForegroundColor Cyan
Write-Host "Visit: https://jackwong94.github.io/AttendanceApp/" -ForegroundColor Cyan