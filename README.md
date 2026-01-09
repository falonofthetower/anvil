# Anvil

A programming language optimized for LLM-driven development.

## Architecture

Two loops:

**Inner Loop (ralph.sh)** - Builds Anvil
- Runs opencode with the prompt
- Commits after each iteration
- Cannot modify itself

**Outer Loop (meta.sh)** - Improves the builder
- Analyzes failures
- Updates LEARNINGS.md
- Can switch models via Ollama API
- Can modify Dockerfile for new dependencies
- Cannot modify ralph.sh, meta.sh, or RALPH_PROMPT.md

## Files

```
FROZEN (never modified by loops):
├── ralph.sh              # Inner loop
├── meta.sh               # Outer loop  
└── RALPH_PROMPT.md       # Core language spec

MODIFIED BY META:
├── ralph-meta/
│   ├── LEARNINGS.md      # Accumulated wisdom
│   ├── PROMPT_ADDITIONS.md  # Extra context for builder
│   └── tools/            # Helper scripts
├── Dockerfile            # Can add dependencies
├── docker-compose.yml    # Can add services
└── .opencode.json        # Can switch models
```

## Prerequisites

On host machine:
```bash
# Ollama running
ollama serve

# At least one coding model
ollama pull qwen2.5-coder:14b
```

## Run

```bash
# Clone
git clone <repo> anvil
cd anvil

# Build container
docker-compose build

# Run the meta loop (recommended)
docker-compose run --rm ralph ./meta.sh

# Or just the inner loop
docker-compose run --rm ralph ./ralph.sh
```

## Monitor

```bash
# Watch progress summary
tail -f ralph-logs/progress.md

# Watch full output
tail -f ralph-logs/session.log

# Watch meta decisions
tail -f ralph-meta/meta.log
```

## Models

Meta can pull and switch models automatically. To pre-pull:
```bash
ollama pull qwen2.5-coder:14b
ollama pull deepseek-coder-v2:16b
ollama pull codellama:13b
```

## Environment Variables

- `RALPH_MAX_ITERATIONS` - Inner loop max (default: 500)
- `RALPH_TARGET_PHASE` - Which phase to target (default: 1)
- `OLLAMA_HOST` - Ollama API URL (default: http://host.docker.internal:11434)
