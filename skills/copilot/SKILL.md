---
name: copilot
version: 1.0.0
description: "Query Synopsys Copilot Knowledge Assistant. Use when user asks about Synopsys EDA tools: VCS, Verdi, PrimeTime, Design Compiler, Fusion Compiler, IC Validator — usage, commands, errors, methodology."
metadata:
---

# Synopsys Copilot

Query Copilot via Dify workflow API, fallback to SSH direct.

## Quick start

```bash
# Via Dify (preferred)
bash ${SKILLS_ROOT}/copilot/scripts/ask_dify.sh "<question>" [--tool vcs]

# Via SSH direct (fallback)
bash ${SKILLS_ROOT}/copilot/scripts/ask.sh "<question>" [--tool vcs]
```

- `${SKILLS_ROOT}` = `~/.claude/skills` or `~/.agents/skills`
- Requires `COPILOT_DIFY_KEY` env var for Dify mode.
- If `COPILOT_DIFY_KEY` is not set, SSH fallback is used automatically.

## Tool mapping

| Keyword | `--tool` |
|---------|----------|
| VCS, compile, simulate, FSDB | vcs |
| Verdi, waveform, debug, nWave | verdi |
| PrimeTime, PT, timing, STA | pt |
| Design Compiler, DC, synthesis | dc |
| Fusion Compiler, FC, floorplan | fc |
| IC Validator, ICV, DRC | icv |

## Dify workflow config

Create a Workflow app in Dify with one HTTP Request node:
- URL: `http://localhost:8766/ask`
- Method: POST
- Headers: `Authorization: Bearer synopsys123` + `Content-Type: application/json`
- Body: `{"question": "{{#sys.query#}}", "tool": "{{#inputs.tool#}}"}`
- Set API key as `COPILOT_DIFY_KEY` env var.

## Prerequisites (server 10.9.200.12)

```bash
# 1. Xvfb headless display
Xvfb :99 -ac -screen 0 1600x1200x24 &

# 2. Copilot GUI (reads license from ~/.bashrc)
LIC=$(grep SNPSLMD_LICENSE_FILE ~/.bashrc | head -1 | cut -d'"' -f2)
LM=$(grep LM_LICENSE_FILE ~/.bashrc | head -1 | cut -d'"' -f2)
DISPLAY=:99 SNPSAI_COPILOT_HOME=/AI/platform/synopsys/copilot/Y-2026.03-SP1 \
  SNPSLMD_LICENSE_FILE="$LIC" LM_LICENSE_FILE="$LM" \
  nohup /AI/platform/synopsys/copilot/Y-2026.03-SP1/copilot -tool vcs &

# 3. HTTP API server
nohup python3 ~/copilot_server.py --port 8766 --api-key synopsys123 &
```

## Execution rules

1. Infer `--tool` from user's question keywords.
2. Pass full question as argument.
3. Present answer in Chinese, organized.
4. Prefer Dify mode; SSH fallback if Dify unavailable.
