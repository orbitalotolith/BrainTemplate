---
tags: [reference, mlx, python, apple-silicon]
created: 2026-04-07
---

# MLX Local Inference (mlx-lm)

Apple's ML framework for local model inference on Apple Silicon. Python package: `mlx-lm` (imports as `mlx_lm`).

## API

- `mlx_lm.load(model_id)` — loads from HuggingFace repo ID or local path. Returns `(model, tokenizer)`. Triggers `huggingface_hub.snapshot_download` on first call.
- `mlx_lm.generate(model, tokenizer, prompt, **kwargs)` — returns plain `str`, no token counts.
- `mlx_lm.stream_generate(model, tokenizer, prompt, **kwargs)` — yields `GenerationResponse` dataclass with accurate token counts and timing.

## Gotchas

- **stream_generate text is incremental** (as of v0.31.x): Each yielded `GenerationResponse.text` is `detokenizer.last_segment` — a delta, not cumulative. Must concatenate all `.text` fields. The final yield includes the finalized last segment.

- **Temperature is NOT a direct parameter** (as of v0.31.x): `stream_generate` and `generate_step` do not accept a `temp` or `temperature` kwarg. Must create a sampler: `from mlx_lm.sample_utils import make_sampler; sampler = make_sampler(temp=0.7)` and pass as `sampler=` kwarg.

- **GenerationResponse location** (as of v0.31.x): Importable from `mlx_lm.generate`, NOT from `mlx_lm.utils`. Fields: `text`, `token`, `logprobs`, `from_draft`, `prompt_tokens`, `prompt_tps`, `generation_tokens`, `generation_tps`, `peak_memory`, `finish_reason`.

- **Synchronous inference blocks event loop**: All MLX inference is synchronous CPU/GPU-bound work. In async contexts, wrap in `asyncio.to_thread()` to avoid starving the event loop.

- **Unified memory on Apple Silicon**: Models share the same memory pool as the application. A 12B Q4 model uses ~7-8 GB. On 16 GB machines, this leaves ~8 GB for the OS, app, and other processes.

- **HuggingFace cache**: Models download to `~/.cache/huggingface/hub/` by default. Respects `HF_HOME` env var. First load triggers download; subsequent loads are from cache.

- **Chat templates matter**: Use `tokenizer.apply_chat_template(messages, tokenize=False, add_generation_prompt=True)` for proper special token handling. Raw string concatenation bypasses model-specific turn markers (e.g., Gemma's `<start_of_turn>` tokens) and degrades output quality.

- **Gemma thinking output consumes all tokens** (as of v0.31.x, Gemma 3/4 models): Gemma models emit `<|channel>thought` reasoning blocks in their output that can consume the entire `max_tokens` budget, leaving no room for the actual response. Fix: pass `enable_thinking=False` in the `apply_chat_template()` call. Additionally, strip `<|channel>thought...` content from the final output as a fallback, since some models ignore the flag.
