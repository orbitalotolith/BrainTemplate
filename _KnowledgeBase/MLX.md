---
tags: [reference, mlx, inference, apple-silicon]
---

# MLX / MLX-LM

## mlx_lm.server (as of mlx-lm 0.31)

### No embeddings endpoint
`mlx_lm.server` only exposes:
- `POST /v1/completions`
- `POST /v1/chat/completions`
- `GET /v1/models`
- `GET /health`

There is NO `/v1/embeddings` endpoint. For OpenAI-compatible embeddings, write a FastAPI wrapper using `sentence-transformers`.

### Command syntax changed in 0.31
```bash
# Correct (0.31+)
uv run mlx_lm.server --model mlx-community/<model> --port 8080

# Deprecated (will warn and may break)
python -m mlx_lm.server ...
```

### /v1/models shared registry quirk
Multiple `mlx_lm.server` processes share a model registry via IPC. Each server's `/v1/models` response lists ALL running mlx_lm model IDs, not just its own. Cosmetic only — each process exclusively serves its own loaded model.

### One model per server instance
Each `mlx_lm.server` process loads exactly one model at startup. For multiple models, run multiple processes on different ports.

## Embeddings with sentence-transformers (Apple Silicon)

### nomic-embed-text-v1.5 requirements
```python
from sentence_transformers import SentenceTransformer
model = SentenceTransformer('nomic-ai/nomic-embed-text-v1.5', trust_remote_code=True)
# Requires: pip install einops
```
- `trust_remote_code=True` is mandatory
- `einops` package must be installed separately
- Produces 768-dim vectors
- Metal-accelerated on Apple Silicon via PyTorch MPS backend

### mlx-community model naming
- `gemma4:e2b` (Ollama) → `mlx-community/gemma-4-e2b-it-4bit`
- `gemma4:e4b` (Ollama) → `mlx-community/gemma-4-e4b-it-4bit`
- `qwen2.5-coder:14b` (Ollama) → `mlx-community/Qwen2.5-Coder-14B-Instruct-4bit`
- No MLX version of `nomic-embed-text-v1.5` exists in mlx-community — use original HF model with sentence-transformers

## Gotchas
- **No `mlx-community/nomic-embed-text-v1.5`** (as of 2026-04) — use `nomic-ai/nomic-embed-text-v1.5` with sentence-transformers instead
- **Port conflicts:** When starting MLX servers, verify old llama-server or Ollama processes aren't holding the target ports
- **Memory budget (16GB M4):** Qwen2.5-Coder-14B-4bit (~8GB) + gemma-4-e2b-it-4bit (~1GB) + nomic-embed (~300MB) ≈ 9.5GB total — leaves ample headroom
