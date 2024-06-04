<# 
For more information, see: 
https://documentation.red-gate.com/redgate-clone/using-the-cli/cli-installation
#>

$rgCloneEndpoint = $env:RGCLONE_API_ENDPOINT
if ($rgCloneEndpoint -notlike "http*/"){
    Write-Error "RGCLONE_API_ENDPOINT variable is either not set, or not in correct format"
} 
$rgcloneExe = (Get-Command rgclone).Source
$rgcloneLocation = Split-Path -parent $rgcloneExe

Write-Output "  "
Write-Output " UPDATING rgclone.exe"
Write-Output "  "

$downloadUrl = $rgCloneEndpoint + "cloning-api/download/cli/windows-amd64"
$zipFile = Join-Path -Path $rgCloneLocation -ChildPath "rgclone.zip"
Write-Output "Install parameters:"
Write-Output "  Redgate Clone endpoint is:  $rgCloneEndpoint"
Write-Output "  Download URL is:            $downloadUrl"
Write-Output "  rgclone.exe install dir is: $rgCloneLocation"
Write-Output "  rgclone.exe zip file is:    $zipFile"
Write-Output "  "

Write-Output "  "
Write-Output "Performing installation:"

If (Test-Path $rgcloneExe){
    Write-Output "  Deleting existing rgclone.exe." 
    Remove-Item $rgcloneExe -Force -Recurse | Out-Null
}


If (Test-Path $zipFile){
    Write-Output "  Deleting existing rgclone zip file." 
    Remove-Item $zipFile -Force -Recurse | Out-Null
}

Write-Output "  Downloading rgclone.exe zip file..."
Write-Output "    from: $downloadUrl"
Write-Output "    to:   $zipFile"
Invoke-WebRequest -Uri $downloadUrl -OutFile $zipFile

Write-Output "  Extracting zip to: $rgCloneLocation"
Add-Type -assembly "System.IO.Compression.Filesystem";
[IO.Compression.Zipfile]::ExtractToDirectory($zipFile, $rgCloneLocation);

Write-Output ""
Write-Output "INSTALL COMPLETE!"
Write-Output "Your files are saved at:"
Write-Output "  $rgCloneLocation"