$gitParentDirs = @(
    "C:\git",
    "C:\git\Demos",
    "C:\git\Admin"
)

$successCount = 0
$failCount = 0
$skipCount = 0

Foreach ($parentDir in $gitParentDirs){
    Write-Host "Performing git pull on all repos in: $parentDir" -ForegroundColor Cyan

    if (-not (Test-Path $parentDir)) {
        Write-Host "  Directory not found: $parentDir" -ForegroundColor Yellow
        continue
    }

    # Get all child directories in the parent directory
    $childDirectories = Get-ChildItem -Path $parentDir -Directory -ErrorAction SilentlyContinue

    Foreach ($dir in $childDirectories) {
        $repoPath = $dir.FullName

        # Check if the .git directory exists in the repository path
        if (Test-Path -Path "$repoPath\.git") {
            Write-Host "  $($dir.Name): Pulling changes..." -ForegroundColor Gray
            $pullOutput = & git -C $repoPath pull 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  $($dir.Name): Success" -ForegroundColor Green
                $successCount++
            } else {
                Write-Host "  $($dir.Name): Pull failed, forcing reset to remote..." -ForegroundColor Yellow
                $branch = & git -C $repoPath rev-parse --abbrev-ref HEAD 2>$null
                & git -C $repoPath fetch --all 2>&1 | Out-Null
                & git -C $repoPath reset --hard "origin/$branch" 2>&1 | Out-Null
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "  $($dir.Name): Reset successful" -ForegroundColor Green
                    $successCount++
                } else {
                    Write-Host "  $($dir.Name): Failed" -ForegroundColor Red
                    $failCount++
                }
            }
        } else {
            Write-Host "  $($dir.Name): Not a git repository, skipping" -ForegroundColor DarkGray
            $skipCount++
        }
    }
    Write-Host ""
}

Write-Host "Summary: $successCount successful, $failCount failed, $skipCount skipped" -ForegroundColor Cyan
