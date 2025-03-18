# ===========================
# Script Name: 01_Startup-Create-Autopilot-Databases.ps1
# Version: 1.0.0
# Author: Chris Hawkins (Redgate Software Ltd)
# Last Updated: 2025-03-18
# Description: Automatically create Autopilot databases on SalesDemoVM startup
# ===========================

$ScriptVersion = "1.0.0"

Write-Host "Running Autopilot Startup Database Creation Script - Version $ScriptVersion"

$ErrorActionPreference = "Stop"

# Define SQL script path
$SQLScriptPath = "C:\git\Demos\Flyway-AutoPilot-FastTrack-GitHub\Scripts\CreateAutoPilotDatabases.sql"

# Log Path Location
$LogPath = "C:\Temp\SQLStartup.log"

# Define the default SQL Server instance (localhost)
$SQLInstance = "localhost"

if ($env:VM_CONFIG -eq 'CustomerVM') {
    Write-Host "Template VM '$env:VM_CONFIG' Detected - Exiting Gracefully"
    exit 0
} if ($env:VM_CONFIG -eq 'SalesDemo') {
    Write-Host "Template VM '$env:VM_CONFIG' Detected - Running Autopilot Database Creation Process"
}
else {
    Write-Host "Unknown VM '$env:VM_CONFIG' Detected - Exiting Gracefully"
    exit 0
}

# Ensure dbatools module is installed
if (-not (Get-Module -ListAvailable -Name dbatools)) {
    Write-Host "Installing dbatools module..."
    Install-Module -Name dbatools -Force -AllowClobber -Scope CurrentUser
}

# Import dbatools module
Import-Module dbatools

# Ensure the directory exists
$LogDirectory = Split-Path -Parent $LogPath
if (-Not (Test-Path $LogDirectory)) {
    New-Item -ItemType Directory -Path $LogDirectory -Force | Out-Null
}

# Wait for SQL Server to be ready
Write-Host "Waiting for SQL Server to start..."
$MaxRetries = 30
$RetryCount = 0
while ($RetryCount -lt $MaxRetries) {
    if (Test-DbaConnection -SqlInstance $SQLInstance) {
        Write-Host "SQL Server is ready!"
        break
    } else {
        Write-Host "SQL Server not ready, retrying in 5 seconds..."
        Start-Sleep -Seconds 5
        $RetryCount++
    }
}

if ($RetryCount -eq $MaxRetries) {
    Write-Error "SQL Server did not start within the expected time. Exiting..."
    Exit 1
}

# Check if the SQL script file exists
if (-Not (Test-Path $SQLScriptPath)) {
    Write-Error "SQL script file not found: $SQLScriptPath. Exiting Gracefully...Likely the CustomerVM"
    Exit 1
}

# Execute the SQL script
Write-Host "Executing SQL script: $SQLScriptPath"
Invoke-DbaQuery -SqlInstance $SQLInstance -File $SQLScriptPath

Write-Host "Databases successfully created!"

# Log completion
Add-Content -Path $LogPath -Value "$(Get-Date) - Successfully executed SQL script."

Exit 0
