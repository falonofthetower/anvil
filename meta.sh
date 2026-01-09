#!/bin/bash
# meta.sh - Outer loop that improves the builder
# FROZEN - do not modify
set -euo pipefail

OLLAMA_HOST="${OLLAMA_HOST:-http://host.docker.internal:11434}"
META_DIR="ralph-meta"
LEARNINGS="$META_DIR/LEARNINGS.md"
ADDITIONS="$META_DIR/PROMPT_ADDITIONS.md"
META_LOG="$META_DIR/meta.log"
BUILDER_PROGRESS="ralph-logs/progress.md"
BUILDER_LOG="ralph-logs/session.log"

mkdir -p "$META_DIR/tools"

# Initialize files if they don't exist
[ ! -f "$LEARNINGS" ] && cat > "$LEARNINGS" << 'EOF'
# Learnings

Accumulated wisdom from failed iterations. The builder reads this.

## Rules

## Patterns That Work

## Patterns That Fail

EOF

[ ! -f "$ADDITIONS" ] && cat > "$ADDITIONS" << 'EOF'
# Prompt Additions

Additional context appended to RALPH_PROMPT.md for each builder run.
Meta-loop updates this based on observed failures.

---

EOF

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$META_LOG"
}

# Pull a model via Ollama API
pull_model() {
    local model="$1"
    log "Pulling model: $model"
    curl -s -X POST "$OLLAMA_HOST/api/pull" \
        -H "Content-Type: application/json" \
        -d "{\"name\": \"$model\"}" | while read -r line; do
        status=$(echo "$line" | jq -r '.status // empty' 2>/dev/null)
        [ -n "$status" ] && echo "  $status"
    done
    log "Model $model ready"
}

# List available models
list_models() {
    curl -s "$OLLAMA_HOST/api/tags" | jq -r '.models[].name' 2>/dev/null
}

# Switch to a different model
switch_model() {
    local model="$1"
    log "Switching to model: $model"
    
    # Check if model exists, pull if not
    if ! list_models | grep -q "^$model$"; then
        pull_model "$model"
    fi
    
    # Update .opencode.json
    cat > .opencode.json << EOF
{
  "provider": "ollama",
  "model": "$model",
  "baseUrl": "$OLLAMA_HOST"
}
EOF
    log "Model switched to $model"
}

# Analyze builder failures and extract learnings
analyze_failures() {
    log "Analyzing builder session..."
    
    # Create analysis prompt
    local analysis_prompt=$(cat << 'EOF'
Analyze the builder's session log and progress. Identify:

1. Repeated failures - same error multiple times
2. Patterns that worked - approaches that made progress
3. Patterns that failed - approaches that wasted iterations
4. Missing tools - things the builder needed but didn't have
5. Model limitations - tasks the model struggled with

Output as structured sections for LEARNINGS.md

Be concise. Only note significant patterns.
EOF
)
    
    # Feed recent logs to opencode for analysis
    {
        echo "$analysis_prompt"
        echo ""
        echo "## Recent Progress:"
        tail -100 "$BUILDER_PROGRESS" 2>/dev/null || echo "No progress yet"
        echo ""
        echo "## Recent Errors (last 200 lines of log):"
        tail -200 "$BUILDER_LOG" 2>/dev/null | grep -i "error\|fail\|panic" | tail -50 || echo "No errors found"
    } | opencode 2>&1 | tee -a "$META_LOG"
}

# Decide if we need to change models
evaluate_model() {
    local current_model=$(jq -r '.model' .opencode.json 2>/dev/null || echo "unknown")
    log "Current model: $current_model"
    
    # Check for signs the model is struggling
    if [ -f "$BUILDER_LOG" ]; then
        local recent_errors=$(tail -500 "$BUILDER_LOG" | grep -c -i "error\|fail" || echo 0)
        local iterations=$(grep -c "^### Iteration" "$BUILDER_PROGRESS" 2>/dev/null || echo 0)
        
        if [ "$iterations" -gt 20 ] && [ "$recent_errors" -gt 50 ]; then
            log "High error rate detected. Consider switching models."
            return 1
        fi
    fi
    return 0
}

# Check if Dockerfile changed and rebuild needed
check_rebuild() {
    if [ -f "$META_DIR/.dockerfile_hash" ]; then
        local old_hash=$(cat "$META_DIR/.dockerfile_hash")
        local new_hash=$(md5sum Dockerfile | cut -d' ' -f1)
        if [ "$old_hash" != "$new_hash" ]; then
            log "Dockerfile changed, rebuild needed"
            return 0
        fi
    fi
    return 1
}

# Save Dockerfile hash
save_dockerfile_hash() {
    md5sum Dockerfile | cut -d' ' -f1 > "$META_DIR/.dockerfile_hash"
}

# Update prompt additions based on learnings
update_additions() {
    log "Updating prompt additions..."
    
    local update_prompt=$(cat << 'EOF'
Based on the LEARNINGS.md file, generate concise additions to help the builder.

Format as a markdown section that will be appended to the main prompt.
Focus on:
- Specific "do this" / "don't do this" rules
- Workarounds for known issues
- Helpful commands or patterns

Keep it under 50 lines. Be direct.
EOF
)
    
    {
        echo "$update_prompt"
        echo ""
        echo "## Current Learnings:"
        cat "$LEARNINGS"
    } | opencode 2>&1 > "$ADDITIONS.new"
    
    # Only update if we got meaningful output
    if [ -s "$ADDITIONS.new" ] && [ $(wc -l < "$ADDITIONS.new") -gt 5 ]; then
        mv "$ADDITIONS.new" "$ADDITIONS"
        log "Prompt additions updated"
    else
        rm -f "$ADDITIONS.new"
        log "No significant additions generated"
    fi
}

# Main meta loop
main() {
    log "=== Meta Loop Starting ==="
    log "Ollama host: $OLLAMA_HOST"
    
    # Ensure we have at least one model
    if ! list_models | head -1 | grep -q .; then
        log "No models found, pulling default..."
        pull_model "qwen2.5-coder:14b"
    fi
    
    save_dockerfile_hash
    
    local meta_iteration=0
    
    while true; do
        meta_iteration=$((meta_iteration + 1))
        log "=== Meta Iteration $meta_iteration ==="
        
        # Run builder (inner loop)
        log "Starting builder..."
        ./ralph.sh RALPH_PROMPT.md || true
        
        # Builder finished or failed - analyze
        log "Builder stopped, analyzing..."
        
        # Check for completion
        if grep -q "ANVIL_COMPLETE" "$BUILDER_LOG" 2>/dev/null; then
            log "=== ANVIL COMPLETE ==="
            exit 0
        fi
        
        # Analyze what happened
        analyze_failures
        
        # Update learnings (append analysis to LEARNINGS.md)
        log "Updating learnings..."
        
        # Evaluate if model switch needed
        if ! evaluate_model; then
            log "Considering model switch..."
            # Try a different model - cycle through options
            case $(jq -r '.model' .opencode.json) in
                *"qwen"*)
                    switch_model "deepseek-coder-v2:16b"
                    ;;
                *"deepseek"*)
                    switch_model "codellama:13b"
                    ;;
                *)
                    switch_model "qwen2.5-coder:14b"
                    ;;
            esac
        fi
        
        # Update prompt additions
        update_additions
        
        # Check if rebuild needed
        if check_rebuild; then
            log "Rebuilding container..."
            docker-compose build
            save_dockerfile_hash
        fi
        
        log "Restarting builder with updates..."
        sleep 5
    done
}

main "$@"
