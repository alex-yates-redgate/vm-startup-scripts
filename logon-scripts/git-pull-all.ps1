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
            # Execute git pull in the repository path
            & git -C $repoPath pull | out-null
        } else {
            Write-Host "- ${repoPath}: .git not file found. Skipping..."
        }
    }
    Write-Host ""
}
