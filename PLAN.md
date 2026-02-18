# The Grid v1 — Engine Plan

## Context

The dashboard shell is complete (accounts, auth, agents CRUD, skills, settings, navigation). Now we need the engine — the core that makes agents actually run. This plan covers the full engine architecture, built incrementally.

v0's engine is ~2000 lines of stdlib Python. v1 rebuilds it in Ruby, following Rails conventions, with a cleaner provider abstraction.

## Phase 1: Docker Lifecycle

Make agents start and stop as Docker containers from the dashboard.

### Agent Container Model

In v0, each agent runs as a **platform container** (`thegrid-agent-{name}`) that:
- Runs `agent_runner.py` — the LLM loop + channel polling
- Has access to Docker socket (to manage its own sandbox container)
- Mounts brain/, workspace/, config.db, etc.

In v1, the Rails app **is** the platform. It runs directly on the server. So:
- No platform containers per agent
- The Rails app manages agent processes directly
- Sandbox containers are still needed for untrusted code execution

### Agent Execution Model (deferred)

Solid Queue is **not a good fit** for long-running agent loops. It's designed for discrete jobs (enqueue, process, complete), not persistent daemons. Issues:
- No way to signal a specific running job to stop (must poll a DB flag)
- Long-running jobs tie up worker slots
- Fighting the tool's design

**Run cycle pattern** (for when we build this): Each agent has a `run_cycle` integer. Awaken/reboot increments the cycle and starts a new loop. The loop checks `run_cycle` each iteration — if it changed, someone else took over or we were suspended, so exit. No waiting for the old loop to finish on reboot.

**Execution approach TBD** — will decide when building channels (Phase 6), since that's when we know what the loop actually needs:
- Most channels need persistent polling/connections (Telegram long-poll, Discord websocket, IMAP, etc.)
- Web chat and API could be event-driven (message created → job enqueued)
- Options: thread pool via singleton (`AgentManager`), Puma plugin, or separate Procfile process

For now, Phase 1 just wires up **status transitions and UI**. No actual execution.

### What to Build

**Model: `Agent` updates**
- Add lifecycle methods: `awaken!`, `suspend!`, `reboot!`
- Status transitions: `asleep → running`, `running → asleep`, `running → running` (reboot)
- Add `run_cycle` integer column (increments on each awaken/reboot/suspend)

**Sandbox: `Agent::Sandbox`** (deferred to Phase 4 — needed for tool execution, not lifecycle)

**Controller actions**
- `POST /agents/:id/awakening` — awaken (create resource)
- `DELETE /agents/:id/awakening` — suspend (destroy resource)
- Follows Rails CRUD convention: awakening is a resource, not a custom action

**Dashboard UI**
- Awaken/Suspend button on agent show page
- Status updates via Turbo Streams

### Files to Create/Modify

```
app/models/agent.rb                          — add lifecycle methods + run_cycle
app/controllers/agents/awakenings_controller.rb — lifecycle endpoints
app/views/agents/show.html.erb               — awaken/suspend buttons
config/routes.rb                             — nested awakening resource
```

---

## Phase 2: Provider Abstraction + LLM Loop

### Provider Interface

All providers normalize to a common interface. Internally everything speaks Chat Completions format (messages array with roles).

```ruby
# app/models/provider.rb (or app/models/provider/base.rb)
class Provider::Base
  def chat(messages:, model:, tools: nil, stream: nil)
    # Returns { content:, tool_calls:, usage: }
  end
end
```

**Providers to support (in order):**
1. `Provider::OpenRouter` — first, uses standard Chat Completions API
2. `Provider::OpenAI` — standard OpenAI API (api key based)
3. `Provider::Anthropic` — Messages API (different format, needs translation)
4. `Provider::OpenAISubscription` — ChatGPT subscription via Codex endpoint (Responses API format, OAuth)

Each provider handles its own:
- Authentication (API key, OAuth tokens, etc.)
- Request format translation (if needed)
- Response normalization back to common shape
- Streaming (SSE parsing)
- Error handling and retries

### Provider Configuration

```
Account-level:
  - default_provider (e.g. "openrouter")
  - provider credentials stored in credentials table (encrypted)

Agent-level override:
  - agent.provider (optional, falls back to account default)
  - agent.model (optional, falls back to account default)
```

### Files to Create

```
app/models/provider/base.rb                  — shared interface
app/models/provider/open_router.rb           — OpenRouter adapter
app/models/provider/open_ai.rb               — OpenAI API adapter (later)
app/models/provider/anthropic.rb             — Anthropic adapter (later)
```

---

## Phase 3: Engine Core

The LLM conversation loop. Takes a message, builds context, calls provider, handles tool calls, returns response.

### Engine Flow (per message)

1. Build system prompt: identity + personality + instructions + skills + time
2. Recall relevant memories (semantic search)
3. Load conversation history (scoped to channel/conversation)
4. Call provider with messages + tools
5. If tool calls → execute via tool handler, loop back to step 4
6. If text response → persist messages, run compaction check, return

### Files to Create

```
app/models/agent/engine.rb                   — main LLM loop
app/models/agent/prompt_builder.rb           — system prompt assembly
app/models/agent/conversation.rb             — conversation history model
```

---

## Phase 4: Tool System

### Tool Types

- **Platform tools** — run in Rails process (web_search, web_fetch, remember, personality)
- **Sandbox tools** — run in Docker container (exec, install_package)
- **Custom tools** — agent-registered scripts in workspace, run in sandbox

### Files to Create

```
app/models/agent/tool_registry.rb            — tool definitions + dispatch
app/models/agent/tools/web_search.rb         — individual tool implementations
app/models/agent/tools/web_fetch.rb
app/models/agent/tools/remember.rb
app/models/agent/tools/exec.rb
... etc
```

---

## Phase 5: Memory System

### Memory Lifecycle

Same as v0: active memories are vector-recalled, dormant are archived.

- Embeddings via API (OpenAI text-embedding-3-small or provider equivalent)
- Cosine similarity in Ruby (or SQLite extension)
- Compaction: when topic shifts, summarize and store as long-term memory
- Auto-demotion: age + importance + access frequency scoring

### Models

```
app/models/memory.rb                         — Memory belongs_to agent
  - content, embedding, state (active/dormant), importance, access_count
app/models/agent/memory_recall.rb            — semantic search logic
app/models/agent/compactor.rb                — topic shift detection + summarization
```

---

## Phase 6: Channels

Thin adapters that receive messages and feed them to the engine.

- **Telegram** — long-polling in the agent's background job
- **Web chat** — via the dashboard (ActionCable / Turbo Streams)
- **API** — REST endpoint for external integrations

---

## Implementation Order

1. **Docker lifecycle** (Phase 1) — agents can start/stop
2. **Provider + OpenRouter** (Phase 2) — can make LLM calls
3. **Engine core** (Phase 3) — message → LLM → response loop
4. **Basic tools** (Phase 4) — exec, web_search, remember
5. **Memory** (Phase 5) — recall, compaction, demotion
6. **Telegram channel** (Phase 6) — first real channel
7. **Web chat channel** (Phase 6) — dashboard messaging

Each phase is independently shippable and testable.
