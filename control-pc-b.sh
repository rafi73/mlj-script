#!/usr/bin/env bash
# Run this on PC A, from Git Bash or WSL.
# With no arguments it opens a command line on PC B.
# With arguments it runs that command on PC B and exits.
#
# Examples:
#   ./control-pc-b.sh
#   ./control-pc-b.sh "powershell -NoProfile -Command Get-ComputerInfo"
#   ./control-pc-b.sh "powershell -NoProfile -ExecutionPolicy Bypass -File C:/Users/Admin/Documents/Assesment/install-dev-tools.ps1"

set -euo pipefail

REMOTE_USER="CHANGE_ME"
REMOTE_HOST="CHANGE_ME"   # Tailscale IP or hostname of PC B

if [[ "${REMOTE_USER}" == "CHANGE_ME" || "${REMOTE_HOST}" == "CHANGE_ME" ]]; then
  echo "Edit REMOTE_USER and REMOTE_HOST in this script first." >&2
  exit 1
fi

if [[ $# -eq 0 ]]; then
  exec ssh -o StrictHostKeyChecking=accept-new "${REMOTE_USER}@${REMOTE_HOST}"
fi

exec ssh -o StrictHostKeyChecking=accept-new "${REMOTE_USER}@${REMOTE_HOST}" "$@"
