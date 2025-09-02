$gitParentDirs = @(
    "C:\git",
    "C:\git\Demos",
    "C:\git\Admin"
)

Foreach ($parentDir in $gitParentDirs){
    Write-Host "Performing a git pull on all the repos in: $parentDir"

    # Get all child directories in the parent directory
    $childDirectories = Get-ChildItem -Path $parentDir -Directory

    Foreach ($dir in $childDirectories) {
        $repoPath = $dir.FullName

        # Check if the .git directory exists in the repository path
		if (Test-Path -Path "$repoPath\.git") {
			Write-Host "- ${repoPath}: .git file found. Pulling changes..."
			& git -C $repoPath pull | Out-Null
			if ($LASTEXITCODE -ne 0) {
				Write-Host "- ${repoPath}: Pull failed, forcing reset to latest remote branch..."
				$branch = & git -C $repoPath rev-parse --abbrev-ref HEAD
				& git -C $repoPath fetch --all
				& git -C $repoPath reset --hard origin/$branch
			}
		} else {
			Write-Host "- ${repoPath}: .git not file found. Skipping..."
		}
    }
    Write-Host ""
}
