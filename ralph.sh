#!/bin/bash
set -euo pipefail

PROMPT_FILE="${1:-RALPH_PROMPT.md}"
MAX_ITERATIONS="${RALPH_MAX_ITERATIONS:-500}"
TARGET_PHASE="${RALPH_TARGET_PHASE:-1}"
COMPLETION_SIGNAL="ANVIL_PHASE_${TARGET_PHASE}_COMPLETE"

mkdir -p ralph-logs
LOG="ralph-logs/$(date +%Y%m%d_%H%M%S).log"

# Init git if needed
[ ! -d .git ] && git init && git add -A && git commit -m "init" || true

echo "Starting Ralph: max=$MAX_ITERATIONS, target=$COMPLETION_SIGNAL"
echo "Log: $LOG"

for i in $(seq 1 $MAX_ITERATIONS); do
    echo "=== Iteration $i ===" | tee -a "$LOG"
    
    # Commit previous changes
    git add -A && git commit -m "iteration $((i-1))" 2>/dev/null || true
    
    # Run opencode with prompt
    cat "$PROMPT_FILE" | opencode 2>&1 | tee -a "$LOG"
    
    # Check completion
    if grep -q "$COMPLETION_SIGNAL" "$LOG"; then
        echo "Done at iteration $i"
        exit 0
    fi
    
    sleep 2
done

echo "Hit max iterations"
exit 1
