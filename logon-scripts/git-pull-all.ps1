$gitParentDir = "C:\git"

# Get all child directories in the parent directory
$childDirectories = Get-ChildItem -Path $gitParentDir -Directory

Foreach ($dir in $childDirectories) {
    $repoPath = $dir.FullName

    # Check if the .git directory exists in the repository path
    if (Test-Path -Path "$repoPath\.git") {
        Write-Host "Pulling changes for repository: $repoPath"
        # Execute git pull in the repository path
        & git -C $repoPath pull
    } else {
        Write-Host "No .git directory found in: $repoPath"
    }
}