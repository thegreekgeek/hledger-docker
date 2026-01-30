#!/bin/bash

echo "host:         ${HLEDGER_HOST:=0.0.0.0}"
echo "port:         ${HLEDGER_PORT:=5000}"
echo "base url:     ${HLEDGER_BASE_URL:="http://localhost:$HLEDGER_PORT"}"
echo "input file:   ${HLEDGER_JOURNAL_FILE:=/data/hledger.journal}"
echo "debug level:  ${HLEDGER_DEBUG:=1}"
echo "rules file:   ${HLEDGER_RULES_FILE:=/data/hledger.rules}"
echo "report dir:   ${HLEDGER_REPORT_DIR:=/data/reports}"
echo "allow:        ${HLEDGER_ALLOW:=add}"
echo "extra_args:   ${HLEDGER_ARGS:=$@}"
echo "---------------------------------------------------------------"

# Sidecar: Static Reporting
REPORT_DIR="${HLEDGER_REPORT_DIR:=/data/reports}"
REPORT_PORT=5001

if [ ! -d "$REPORT_DIR" ]; then
    echo "Creating report directory: $REPORT_DIR"
    mkdir -p "$REPORT_DIR"
fi

# Optional: Generate reports on startup
GEN_SCRIPT="/data/generate_reports.sh"
if [ -f "$GEN_SCRIPT" ] && [ -x "$GEN_SCRIPT" ]; then
    echo "Executing report generation script: $GEN_SCRIPT"
    "$GEN_SCRIPT" || echo "Warning: Report generation script failed."
elif [ -f "$GEN_SCRIPT" ]; then
    echo "Warning: Found $GEN_SCRIPT but it is not executable."
fi

echo "Starting static report server on port $REPORT_PORT..."
# Use -u for unbuffered output so logs appear immediately in docker logs
python3 -u -m http.server "$REPORT_PORT" --directory "$REPORT_DIR" --bind 0.0.0.0 &
HTTP_PID=$!
echo "Static report server started with PID $HTTP_PID"

# Trap signals to kill the background process
trap "kill $HTTP_PID" EXIT

exec hledger-web \
     --server \
     --host=$HLEDGER_HOST \
     --port=$HLEDGER_PORT \
     --file="$HLEDGER_JOURNAL_FILE" \
     --debug=$HLEDGER_DEBUG \
     --base-url=$HLEDGER_BASE_URL \
     --rules-file="$HLEDGER_RULES_FILE" \
     --allow="$HLEDGER_ALLOW" \
     ${HLEDGER_ARGS:="$@"}