# Anvil

A programming language optimized for LLM-driven development.

## Ralph Setup

Runs OpenCode against Ollama on the host machine.

### Prerequisites

On host:
```bash
# Ollama running with a coding model
ollama pull qwen2.5-coder:32b
# or for 16GB VRAM:
ollama pull qwen2.5-coder:14b
```

### Run

```bash
docker-compose build
docker-compose run --rm ralph

# Inside container:
ralph RALPH_PROMPT.md
```

### Config

Edit `.opencode.json` to change model:
```json
{
  "provider": "ollama", 
  "model": "qwen2.5-coder:14b",
  "baseUrl": "http://host.docker.internal:11434"
}
```

### Environment

- `RALPH_MAX_ITERATIONS` - default 500
- `RALPH_TARGET_PHASE` - 1, 2, 3, or "complete"
