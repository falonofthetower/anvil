#!/bin/bash
# ralph.sh - Inner loop that builds Anvil
# FROZEN - do not modify
set -euo pipefail

PROMPT_FILE="${1:-RALPH_PROMPT.md}"
MAX_ITERATIONS="${RALPH_MAX_ITERATIONS:-500}"
TARGET_PHASE="${RALPH_TARGET_PHASE:-1}"
COMPLETION_SIGNAL="ANVIL_PHASE_${TARGET_PHASE}_COMPLETE"

META_DIR="ralph-meta"
ADDITIONS="$META_DIR/PROMPT_ADDITIONS.md"
LEARNINGS="$META_DIR/LEARNINGS.md"

mkdir -p ralph-logs
LOG="ralph-logs/session.log"
PROGRESS="ralph-logs/progress.md"

# Init git if needed
[ ! -d .git ] && git init && git add -A && git commit -m "init" || true

# Build the full prompt (core + additions + learnings)
build_prompt() {
    cat "$PROMPT_FILE"
    
    if [ -f "$ADDITIONS" ]; then
        echo ""
        echo "---"
        echo "## Additional Context (from meta-loop)"
        echo ""
        cat "$ADDITIONS"
    fi
    
    if [ -f "$LEARNINGS" ]; then
        echo ""
        echo "---"
        echo "## Learnings (from previous attempts)"
        echo ""
        cat "$LEARNINGS"
    fi
}

# Initialize progress file
cat > "$PROGRESS" << EOF
# Ralph Progress

**Started:** $(date)
**Target:** $COMPLETION_SIGNAL
**Max Iterations:** $MAX_ITERATIONS

## Status: RUNNING

## Iterations

EOF

echo "Starting Ralph: max=$MAX_ITERATIONS, target=$COMPLETION_SIGNAL"
echo "Watch progress: tail -f ralph-logs/progress.md"
echo "Full log: tail -f ralph-logs/session.log"

for i in $(seq 1 $MAX_ITERATIONS); do
    echo "" | tee -a "$LOG"
    echo "========================================" | tee -a "$LOG"
    echo "=== Iteration $i of $MAX_ITERATIONS ===" | tee -a "$LOG"
    echo "=== $(date) ===" | tee -a "$LOG"
    echo "========================================" | tee -a "$LOG"
    
    # Update progress file
    echo "### Iteration $i - $(date '+%H:%M:%S')" >> "$PROGRESS"
    
    # Commit previous changes
    if git add -A && git commit -m "iteration $((i-1))" 2>/dev/null; then
        CHANGED=$(git diff --stat HEAD~1 2>/dev/null | tail -1 || echo "no changes")
        echo "- Committed: $CHANGED" >> "$PROGRESS"
    fi
    
    # Run opencode with full prompt
    ITER_START=$(date +%s)
    build_prompt | opencode 2>&1 | tee -a "$LOG"
    ITER_END=$(date +%s)
    ITER_DURATION=$((ITER_END - ITER_START))
    
    echo "- Duration: ${ITER_DURATION}s" >> "$PROGRESS"
    
    # Check what files changed
    FILES_CHANGED=$(git status --porcelain | wc -l)
    echo "- Files touched: $FILES_CHANGED" >> "$PROGRESS"
    
    # List new/modified files
    if [ "$FILES_CHANGED" -gt 0 ]; then
        echo '```' >> "$PROGRESS"
        git status --porcelain | head -10 >> "$PROGRESS"
        [ "$FILES_CHANGED" -gt 10 ] && echo "... and $((FILES_CHANGED - 10)) more" >> "$PROGRESS"
        echo '```' >> "$PROGRESS"
    fi
    
    echo "" >> "$PROGRESS"
    
    # Check completion
    if grep -q "$COMPLETION_SIGNAL" "$LOG"; then
        echo "## Status: COMPLETE at iteration $i" >> "$PROGRESS"
        echo "**Finished:** $(date)" >> "$PROGRESS"
        git add -A && git commit -m "Phase $TARGET_PHASE complete at iteration $i" || true
        echo "Done at iteration $i"
        exit 0
    fi
    
    sleep 2
done

echo "## Status: MAX ITERATIONS REACHED" >> "$PROGRESS"
echo "**Finished:** $(date)" >> "$PROGRESS"
echo "Hit max iterations"
exit 1
