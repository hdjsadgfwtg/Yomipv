param([string]$mpvPid = "", [string]$ipcPipe = "", [string]$allowCopy = "0")

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $scriptDir

$logFile = Join-Path $scriptDir "launch.log"

"--- PowerShell Startup Check: $(Get-Date) ---" | Out-File $logFile -Encoding UTF8
"Script Dir: $scriptDir" | Out-File $logFile -Append -Encoding UTF8
"MPV PID: $mpvPid" | Out-File $logFile -Append -Encoding UTF8

$lookupAppCmd = Join-Path $scriptDir "node_modules\.bin\electron.cmd"

if (-not (Test-Path $lookupAppCmd)) {
    "[ERROR] Lookup App not found at $lookupAppCmd" | Out-File $logFile -Append
    exit 1
}

# Start app in background
# Hide console window
# Set working directory for main.js discovery
# Start app as a background process with output redirection
"[INFO] Starting Lookup App..." | Out-File $logFile -Append -Encoding UTF8
try {
    # Redirect output to capture logs
    $stdOut = Join-Path $scriptDir "lookup_app_stdout.log"
    $stdErr = Join-Path $scriptDir "lookup_app_stderr.log"
    
    $lookupAppArgs = @(".", "--parent-pid=$mpvPid", "--ipc-pipe=$ipcPipe", "--allow-copy=$allowCopy")
    Start-Process -FilePath $lookupAppCmd -ArgumentList $lookupAppArgs -WorkingDirectory $scriptDir -WindowStyle Hidden -RedirectStandardOutput $stdOut -RedirectStandardError $stdErr
    "[INFO] Lookup App process started. Logs at lookup_app_stdout.log and lookup_app_stderr.log" | Out-File $logFile -Append -Encoding UTF8
} catch {
    "[ERROR] Failed to start Lookup App: $_" | Out-File $logFile -Append
    exit 1
}
