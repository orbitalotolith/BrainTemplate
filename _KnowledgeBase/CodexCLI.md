---
tags: [reference, ai-providers, openai]
---

# OpenAI Codex CLI (`@openai/codex`)

Third-party harness for OpenAI's coding-agent models (gpt-5.4, o3, o4-mini, etc.) using ChatGPT subscription auth instead of API keys.

## Install & Auth

```bash
npm install -g @openai/codex
codex login               # interactive — opens http://localhost:1455 browser OAuth
codex login status        # exit 0 if logged in, 1 "Not logged in" otherwise
```

Token lives at `~/.codex/auth.json.tokens.access_token`.

## Non-interactive completion

```bash
codex exec --json --skip-git-repo-check --ignore-rules --ignore-user-config \
  --model gpt-5.4 "prompt text"
```

Output is **JSONL event stream**, NOT a single JSON object:

```jsonl
{"type":"thread.started","thread_id":"..."}
{"type":"turn.started"}
{"type":"item.completed","item":{"id":"item_0","type":"agent_message","text":"..."}}
{"type":"turn.completed","usage":{"input_tokens":12237,"cached_input_tokens":3456,"output_tokens":14}}
```

Parse by concatenating `text` from `item.completed` entries where `item.type == "agent_message"`. Exclude `reasoning` items. Read final `turn.completed.usage` for token counts.

Alternative: `-o FILE / --output-last-message FILE` writes the final agent message to a file (simpler but loses token counts).

## Gotchas

- **~12k input tokens per call due to coding-agent overhead.** Codex loads its system prompt + tool definitions on every `exec`. `--ignore-rules --ignore-user-config` does NOT strip this — the overhead is the agent framework itself. As of `codex-cli 0.122.0` (2026-04-20 release): "Say only pong" burns `input_tokens: 12233, output_tokens: 17`, latency ~5s. Acceptable for low-volume agent routing; **do not use for high-frequency completion**. API key path is mandatory when latency or token cost matters.

- **Probe command is `codex login status`, NOT `codex auth status`.** The latter doesn't exist in v0.122.0. Speculative stubs (including the AgentDashboard spec's original stub) often get this wrong.

- **ChatGPT subscription access_token CANNOT be reused against the public OpenAI API.** `~/.codex/auth.json.tokens.access_token` has scopes `openid profile email offline_access api.connectors.read api.connectors.invoke` only. Curl against `api.openai.com/v1/models` returns `403 "Missing scopes: api.model.read"`. Chat-completions endpoint similarly rejects. As of 2026-04-21, the OpenClaw pattern of using the raw token against `api.openai.com/v1/chat/completions` **does not work** — either the docs are stale or they use an auth path I couldn't reproduce. The only working subscription-auth path is shelling out to `codex exec`.

- **`codex exec --model gpt-5.4` works** (verified 2026-04-21 with v0.122.0). `gpt-5.4` is OpenAI's frontier agentic coding model, Codex-only — NOT available on `api.openai.com/v1/chat/completions` even with an API key.

- **Cost is $0 per call** (subscription covers it), but token counts are still meaningful for budget tracking / capacity planning.

- **Interactive login requires browser.** `codex login` starts a local auth server on `http://localhost:1455` and waits for callback. On headless machines use `codex login --device-auth` for device-code flow.
