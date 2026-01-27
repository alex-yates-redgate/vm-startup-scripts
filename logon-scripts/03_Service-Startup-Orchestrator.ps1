
############################################################
# Sales Demo VM - Service Startup Orchestrator
# Windows Server 2016 - PowerShell 5.1
############################################################

# Determine if running as Administrator
$IsAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)


if (-not $IsAdmin -and -not $IsTaskScheduler) {
    Write-Host "Elevation required. Please relaunch as administrator..." -ForegroundColor Yellow
}

# ==========================================================
# VM CONFIG PRECHECK (your custom logic)
# ==========================================================

if ($env:VM_CONFIG -eq 'CustomerVM') {
    Write-Host "Template VM '$env:VM_CONFIG' Detected - Exiting Gracefully"
    exit 0
}
elseif ($env:VM_CONFIG -eq 'SalesDemo') {
    Write-Host "Template VM '$env:VM_CONFIG' Detected - Running Windows Service Startup Orchestrator"
}
else {
    Write-Host "Unknown VM '$env:VM_CONFIG' Detected - Exiting Gracefully"
    exit 0
}

# ==========================================================
# CONFIGURATION
# ==========================================================

$SqlInstances = @(
    @{ Name = "MSSQLSERVER"; Display = "SQL Server (MSSQLSERVER)" },
    @{ Name = "MSSQL`$TOOLS"; Display = "SQL Server (TOOLS)" }
)

$RetryCount         = 3
$SqlStartupTimeout  = 90
$RecoveryWait       = 20
$LogLookbackMinutes = 30

$SqlCloneServerService = "SQL Clone Server"
$ChinookServiceName    = "ChinookBackend"

$DependentServices = @(
    "vstsagent.localhost.WIN2016-TFS18",
    "Redgate Client"
)

$ServicesToStopLast = @("SEMvNEXT")

$LogDir  = "C:\git\Admin\Logs\Logon_Scripts\"
$LogFile = Join-Path $LogDir "ServiceStartupOrchestrator.log"

if (-not (Test-Path $LogDir)) {
    New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
}

Start-Transcript -Path $LogFile -Append -Force


# ==========================================================
# STATUS LOGGING
# ==========================================================
function Write-Status { param([string]$Message, [ConsoleColor]$Color = "Gray"); Write-Host ("[{0}] {1}" -f (Get-Date -Format "HH:mm:ss"), $Message) -ForegroundColor $Color }

# ==========================================================
# PRECHECK: Ensure Invoke-Sqlcmd exists
# ==========================================================
function Ensure-InvokeSqlCmd {
    if (-not (Get-Command Invoke-Sqlcmd -ErrorAction SilentlyContinue)) {
        Write-Status "Invoke-Sqlcmd not available. Install SSMS or SqlServer PowerShell module." Red
        throw "Invoke-Sqlcmd missing"
    }
}
Ensure-InvokeSqlCmd

# ==========================================================
# SERVICE HELPERS (clean logging)
# ==========================================================
function Ensure-ServiceRunning {
    param([string]$Name, [int]$TimeoutSeconds = 60)

    Write-Status "Ensuring service is running: $Name" Cyan
    try { Start-Service -Name $Name -ErrorAction Stop } catch { Write-Status "Start-Service for ${Name} returned an error. Checking actual status..." DarkYellow }

    $elapsed = 0
    while ($true) {
        try { $svc = Get-Service -Name $Name -ErrorAction Stop } catch { throw "Service ${Name} not found." }
        if ($svc.Status -eq "Running") { Write-Status "Service ${Name} is running" Green; return }
        Start-Sleep -Seconds 2; $elapsed += 2
        if ($elapsed -ge $TimeoutSeconds) { throw "Service ${Name} did not reach Running state." }
    }
}

function Ensure-ServiceRestart {
    param([string]$Name, [int]$TimeoutSeconds = 60)

    Write-Status "Restarting service: ${Name}" Yellow
    try { Restart-Service -Name $Name -Force -ErrorAction Stop } catch { Write-Status "Restart-Service for ${Name} returned an error. Attempting start..." DarkYellow; try { Start-Service -Name $Name -ErrorAction Stop } catch { Write-Status "Start-Service for ${Name} also returned an error. Checking final status..." DarkYellow } }

    $elapsed = 0
    while ($true) {
        try { $svc = Get-Service -Name $Name -ErrorAction Stop } catch { throw "Service ${Name} not found after restart." }
        if ($svc.Status -eq "Running") { Write-Status "Service ${Name} is running after restart" Green; return }
        Start-Sleep -Seconds 2; $elapsed += 2
        if ($elapsed -ge $TimeoutSeconds) { throw "Service ${Name} did not reach Running state after restart." }
    }
}

function Ensure-ChinookBackendRunning {
    param([string]$Name, [int]$TimeoutSeconds = 60)

    try { $svc = Get-Service -Name $Name -ErrorAction Stop } catch { Write-Status "Service ${Name} not found; skipping." Yellow; return }
    if ($svc.Status -eq "Running") {
        Write-Status "${Name} is running. Restarting to load updated files..." Yellow
        try { Restart-Service -Name $Name -Force -ErrorAction Stop } catch { Write-Status "Restart-Service for ${Name} returned an error. Checking status..." DarkYellow }
    } else {
        Write-Status "${Name} is stopped. Starting..." Yellow
        try { Start-Service -Name $Name -ErrorAction Stop } catch { Write-Status "Start-Service for ${Name} returned an error. Checking status..." DarkYellow }
    }

    $elapsed = 0
    while ($true) {
        $svc.Refresh()
        if ($svc.Status -eq "Running") { Write-Status "${Name} is running and active" Green; return }
        Start-Sleep -Seconds 2; $elapsed += 2
        if ($elapsed -ge $TimeoutSeconds) { throw "${Name} did not reach Running state." }
    }
}

# ==========================================================
# SQL HEALTH FUNCTIONS (use SqlInstance, not Windows service name)
# ==========================================================
function Test-SqlConnectivity {
    param([string]$Instance)
    Invoke-Sqlcmd -ServerInstance $Instance -Query "SELECT 1" -QueryTimeout 10 | Out-Null
}

function Get-RecoveryPendingDatabases {
    param([string]$Instance)
    $query = @"
SELECT name, state_desc
FROM sys.databases
WHERE state_desc = 'RECOVERY_PENDING'
"@
    Invoke-Sqlcmd -ServerInstance $Instance -Query $query -QueryTimeout 30
}

function Parse-SqlErrorLog {
    param([string]$Instance, [int]$LookbackMinutes = 30)
    Write-Status "Parsing SQL error log for ${Instance}..." Yellow
    $query = @"
EXEC xp_readerrorlog 0, 1, N'recovery', NULL,
     DATEADD(MINUTE,-$LookbackMinutes,GETDATE()), GETDATE(), N'desc'
"@
    try {
        $rows = Invoke-Sqlcmd -ServerInstance $Instance -Query $query -QueryTimeout 30
        foreach ($row in $rows) { if ($row.Text) { Write-Status "LOG: $($row.Text)" DarkYellow } }
    } catch { Write-Status "Error reading SQL error log for ${Instance}: $_" DarkYellow }
}

# Returns an object describing health and whether we restarted due to recovery pending
function Validate-SqlInstance {
    param([string]$ServiceName, [string]$SqlInstance)

    $attempt = 0
    $restartedDueToRecovery = $false
    $restartedAny = $false

    while ($attempt -lt $RetryCount) {
        $attempt++
        Write-Status "Validating SQL instance ${SqlInstance} (service ${ServiceName}) - attempt $attempt of $RetryCount" Yellow

        # Ensure Windows service is running
        Ensure-ServiceRunning -Name $ServiceName -TimeoutSeconds $SqlStartupTimeout
        Start-Sleep -Seconds $RecoveryWait

        try {
            Test-SqlConnectivity -Instance $SqlInstance
            $pending = Get-RecoveryPendingDatabases -Instance $SqlInstance

            if ($pending -and $pending.Count -gt 0) {
                Write-Status "RECOVERY_PENDING detected on ${SqlInstance}:" Red
                foreach ($db in $pending) { Write-Status " - $($db.name)" Red }
                Parse-SqlErrorLog -Instance $SqlInstance -LookbackMinutes $LogLookbackMinutes

                Write-Status "Restarting service ${ServiceName} to clear recovery pending..." Yellow
                Restart-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
                $restartedDueToRecovery = $true
                $restartedAny = $true
                Start-Sleep -Seconds 20
            }
            else {
                Write-Status "SQL instance ${SqlInstance} healthy." Green
                return [pscustomobject]@{
                    ServiceName                       = $ServiceName
                    SqlInstance                       = $SqlInstance
                    Healthy                           = $true
                    RestartedDueToRecoveryPending     = $restartedDueToRecovery
                    RestartedAny                      = $restartedAny
                }
            }
        }
        catch {
            Write-Status "Connectivity failure for ${SqlInstance}: $_" Red
            Restart-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
            $restartedAny = $true
            Start-Sleep -Seconds 20
        }
    }

    throw "SQL instance ${SqlInstance} failed health checks."
}

# ==========================================================
# SQL CLONE AGENT AUTO-DETECT (Start or Restart)
# ==========================================================
function Select-LatestSqlCloneAgent {
    $candidates = Get-CimInstance Win32_Service | Where-Object { $_.DisplayName -like "SQL Clone Agent*" }
    if (-not $candidates) { return $null }

    if ($candidates.Count -eq 1) { return $candidates[0] }

    # Multiple versions → pick highest semantic version
    $regex = [regex]"(\d+(\.\d+){1,4})"
    $ranked = foreach ($svc in $candidates) {
        $m = $regex.Match($svc.DisplayName)
        $vkey = if ($m.Success) { ($m.Groups[1].Value.Split('.') | ForEach-Object { $_.PadLeft(10,'0') }) -join '.' } else { "0" }
        [pscustomobject]@{ Svc = $svc; VKey = $vkey }
    }
    ($ranked | Sort-Object VKey -Descending | Select-Object -First 1).Svc
}

function Start-LatestSqlCloneAgent {
    Write-Status "Searching for SQL Clone Agent service..." Yellow
    $svc = Select-LatestSqlCloneAgent
    if (-not $svc) { Write-Status "SQL Clone Agent not found." Yellow; return }
    Write-Status "Found SQL Clone Agent: $($svc.DisplayName)" Cyan
    Ensure-ServiceRunning -Name $svc.Name
}

function Restart-LatestSqlCloneAgent {
    Write-Status "Searching for SQL Clone Agent service to restart..." Yellow
    $svc = Select-LatestSqlCloneAgent
    if (-not $svc) { Write-Status "SQL Clone Agent not found; skipping restart." Yellow; return }
    Write-Status "Restarting SQL Clone Agent: $($svc.DisplayName)" Yellow
    Ensure-ServiceRestart -Name $svc.Name
}

# ==========================================================
# MAIN ORCHESTRATION SEQUENCE (Option B: MSSQLSERVER then MSSQL$TOOLS)
# ==========================================================
Write-Status "===== DEMO STARTUP SEQUENCE BEGIN =====" Cyan

# 1) MSSQLSERVER first
$primaryResult = Validate-SqlInstance -ServiceName "MSSQLSERVER"  -SqlInstance "localhost"

# 2) Then MSSQL$TOOLS (track if it was restarted due to RECOVERY_PENDING)
$toolsResult   = Validate-SqlInstance -ServiceName "MSSQL`$TOOLS" -SqlInstance "localhost\TOOLS"

# 3) SQL Clone Server and Agent handling based on TOOLS recovery
if ($toolsResult.RestartedDueToRecoveryPending) {
    Write-Status "TOOLS was restarted due to RECOVERY_PENDING. Restarting SQL Clone components..." Yellow
    Ensure-ServiceRestart -Name $SqlCloneServerService
    Restart-LatestSqlCloneAgent
}
else {
    # Normal path: ensure Clone Server is running, and start/ensure Agent
    Ensure-ServiceRunning -Name $SqlCloneServerService
    Start-LatestSqlCloneAgent
}

# 4) ChinookBackend (Option A)
Ensure-ChinookBackendRunning -Name $ChinookServiceName

# 5) Other dependent services
foreach ($svc in $DependentServices) {
    try { Ensure-ServiceRunning -Name $svc } catch { Write-Status "Could not start ${svc}: $_" Yellow }
}

# 6) Stop final services
foreach ($svc in $ServicesToStopLast) {
    try { Write-Status "Stopping service: ${svc}" Cyan; Stop-Service -Name $svc -ErrorAction SilentlyContinue }
    catch { Write-Status "Failed to stop ${svc}: $_" Yellow }
}

Write-Status "===== STARTUP COMPLETE - DEMO MACHINE READY =====" Green
Stop-Transcript


