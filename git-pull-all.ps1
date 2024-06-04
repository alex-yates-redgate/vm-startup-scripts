$gitParentDir = "C:\git"
Set-Location $gitParentDir
$childDirectories = (Get-ChildItem | Where-Object {$_.Mode -like "d-----"}).Name
Foreach ($dir in $childDirectories){
    Set-Location "$gitParentDir/$dir"
    if (Test-Path ".git"){
        git pull
    }
}
