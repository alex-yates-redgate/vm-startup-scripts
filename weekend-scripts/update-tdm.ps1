# Define the path to the script you want to run
$scriptPath = "C:\git\Demos\TDM-AutoPilot\helper_scripts\InstallTdmClisOnWindows.ps1"

# Check if the script file exists
if (Test-Path -Path $scriptPath) {
    Write-Host "Executing script: $scriptPath"
    
    try {
        # Run the script
        . $scriptPath
        Write-Host "Script executed successfully."
    }
    catch {
        Write-Host "Error executing script."
        Write-Host "Error details: $_"
    }
}
else {
    Write-Host "Script file not found: $scriptPath"
}
