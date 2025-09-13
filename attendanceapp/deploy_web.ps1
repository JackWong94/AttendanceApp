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
    Write-Host "❌ Flutter web build failed. Aborting deployment." -ForegroundColor Red
    exit $LASTEXITCODE
}

# Step 2: Save changes if any
Write-Host "Stashing uncommitted changes..." -ForegroundColor Green
git stash

# Step 3: Switch or create gh-pages branch
if (git show-ref --verify --quiet refs/heads/$BranchName) {
    Write-Host "Switching to existing branch '$BranchName'..." -ForegroundColor Green
    git checkout $BranchName
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to switch to branch '$BranchName'. Exiting script." -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "Creating orphan branch '$BranchName'..." -ForegroundColor Green
    git checkout --orphan $BranchName
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Failed to create orphan branch '$BranchName'. Exiting script." -ForegroundColor Red
        exit 1
    }
}

# Step 4: Backup web build (will only run if branch checkout succeeded)
Write-Host "Backing up web build to temporary folder..." -ForegroundColor Green
if (Test-Path $TempPath) { Remove-Item $TempPath -Recurse -Force }
New-Item -ItemType Directory -Path $TempPath -Force
Copy-Item -Path ".\build\web\*" -Destination $TempPath -Recurse

# Step 5: Clear old files in gh-pages
Write-Host "Clearing old files in '$BranchName' branch..." -ForegroundColor Green
git rm -rf * | Out-Null

# Step 6: Copy web build to gh-pages branch
Write-Host "Copying new web build to '$BranchName' branch..." -ForegroundColor Green
Copy-Item -Path "$TempPath\*" -Destination "." -Recurse

# Step 7: Delete temporary folder
Write-Host "Deleting temporary folder..." -ForegroundColor Green
Remove-Item -Path $TempPath -Recurse -Force

# Step 8: Commit and push to GitHub
Write-Host "Committing and pushing to '$BranchName'..." -ForegroundColor Green
git add .
git commit -m "Deploy Flutter web app"
git push origin $BranchName --force

Write-Host "✅ Deployment complete!" -ForegroundColor Cyan
Write-Host "Visit: https://<username>.github.io/$RepoName/" -ForegroundColor Cyan
