#!/bin/bash
# Linux launcher for Electron lookup app
# Equivalent to start_lookup.ps1 for Windows

MPV_PID="$1"
IPC_PIPE="$2"
ALLOW_COPY="${3:-0}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || exit 1

LOG_FILE="$SCRIPT_DIR/launch.log"

echo "--- Bash Startup Check: $(date) ---" > "$LOG_FILE"
echo "Script Dir: $SCRIPT_DIR" >> "$LOG_FILE"
echo "MPV PID: $MPV_PID" >> "$LOG_FILE"

LOOKUP_APP_BIN="$SCRIPT_DIR/node_modules/.bin/electron"

if [ ! -f "$LOOKUP_APP_BIN" ]; then
    echo "[ERROR] Lookup App binary not found at $LOOKUP_APP_BIN. Please run 'npm install' inside the lookup-app directory." >> "$LOG_FILE"
    exit 1
fi

# Start Lookup App as a background process with output redirection
echo "[INFO] Starting Lookup App..." >> "$LOG_FILE"

STDOUT_LOG="$SCRIPT_DIR/lookup_app_stdout.log"
STDERR_LOG="$SCRIPT_DIR/lookup_app_stderr.log"

# Launch Lookup App with parent PID monitoring and IPC pipe
"$LOOKUP_APP_BIN" . --parent-pid="$MPV_PID" --ipc-pipe="$IPC_PIPE" --allow-copy="$ALLOW_COPY" > "$STDOUT_LOG" 2> "$STDERR_LOG" &

LOOKUP_APP_PID=$!

if [ -n "$LOOKUP_APP_PID" ]; then
    echo "[INFO] Lookup App process started with PID $LOOKUP_APP_PID. Logs at lookup_app_stdout.log and lookup_app_stderr.log" >> "$LOG_FILE"
else
    echo "[ERROR] Failed to start Lookup App" >> "$LOG_FILE"
    exit 1
fi
