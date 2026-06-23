
# My AI

## Prerequisites

We can check if Ollama works:

```bash
ollama --version
```

We can configure Ollama where to store its model:

```bash
ls /Volumes
launchctl setenv OLLAMA_MODELS /Volumes/KSK-TOSHIBA/ollama-models
```

We can pull several models:

```bash
ollama pull qwen2.5:32b
ollama pull qwen2.5:14b
ollama pull phi4
```

And we can see what we already have:

```bash
ollama list
```

But at the same time, we can run only one of them:

```bash
ollama run qwen2.5:32b
ollama run qwen2.5:14b
ollama run phi4
```

## Useful Commands

### How to Build

```bash
dotnet build Src/WissensNest.slnx --no-incremental
```

### How to Run

```bash
dotnet WissensNest.API.dll
```

### How to Ask

Without Web search:

```bash
curl -X POST http://localhost:4000/chat/stream \
  -H "Content-Type: application/json" \
  -d '{
    "history": [],
    "userMessage": "What is a watchdog timer?",
    "useWebSearch": false
  }'
```

With Web search:

```bash
curl -X POST http://localhost:4000/chat/stream \
  -H "Content-Type: application/json" \
  -d '{
    "history": [],
    "userMessage": "What is a watchdog timer?",
    "useWebSearch": true
  }'
```
