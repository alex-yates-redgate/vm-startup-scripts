# Define the directory containing the scripts
$scriptDirectory = "$PSScriptRoot\weekend-scripts"

# Get all .ps1 files in the directory
$scripts = Get-ChildItem -Path $scriptDirectory -Filter *.ps1 | Sort-Object Name

# Loop through each script and execute it
foreach ($script in $scripts) {
    Write-Host "Executing script: $($script.FullName)"
    
    # Execute the script
    try {
        . $script.FullName
        Write-Host "Script executed successfully: $($script.FullName)"
    }
    catch {
        Write-Host "Error executing script: $($script.FullName)"
        Write-Host "Error details: $_"
    }
    
    Write-Host ""
}
