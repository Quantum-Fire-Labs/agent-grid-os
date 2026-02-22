# AgentGridOS

Self-hosted platform for running AI agents with identity, memory, tools, and sandboxed workspaces.

- **Stack**: Rails 8.1, Ruby 4.0, SQLite3, Hotwire (Turbo + Stimulus), Propshaft, importmap
- **Repo**: `Quantum-Fire-Labs/agent-grid-os`
- **Branding**: Always "AgentGridOS" (not "The Grid")

## Commands

```bash
bin/setup --skip-server          # Install deps, DB, build workspace image
bin/dev                          # Start dev server
bin/rails test                   # Unit/integration tests
bin/rails test:system            # System tests (Selenium + Chrome)
bin/rubocop                      # Lint (Rails Omakase style)
bin/brakeman                     # Security scan
bin/bundler-audit                # Gem audit
```

## Architecture

Each agent gets: identity, conversations, memory (semantic recall), tools (27 built-in + custom + plugins), a sandboxed Docker workspace (Ubuntu container), and LLM provider connections.

### Key Files

- `app/models/agent/brain.rb` — reasoning and response generation
- `app/models/agent/prompt_builder.rb` — system prompt construction
- `app/models/agent/tool_registry.rb` — tool discovery and dispatch (checks plugins before built-in tools)
- `app/models/agent/workspace.rb` — Docker workspace container management
- `public/agentgridos_app_sdk.js` — client-side SDK (`window.AgentGridOS`)
- `bin/agentgridos` — production CLI (setup, start, stop, update, logs)
- `install.sh` — remote installer script

### Key Models

- `Account` — tenant/workspace (multi-tenant)
- `Agent` — AI agent instances; submodels in `app/models/agent/` (Brain, Workspace, ToolRegistry, PromptBuilder, Audio, Embedding, MemoryRecall)
- `Provider` / `AgentModel` — LLM provider connections and per-agent model config
- `Conversation` / `Message` / `Participant` — chat sessions
- `Memory` / `MemoryCompaction` — agent long-term memory with semantic recall
- `Plugin` / `AgentPlugin` / `PluginConfig` — plugin system (see below)
- `CustomTool` / `Skill` — user-defined tools and skills
- `CustomApp` / `CustomApp::Table` / `CustomApp::Row` — custom applications
- `KeyChain` — encrypted credential storage

## Plugin System

Bundled plugins live in `lib/plugins/<name>/plugin.yaml` (+ optional `.rb` entrypoint).

- Plugin names use **underscores** (not hyphens) — hyphens break Zeitwerk autoloading
- `lib/plugins` is excluded from Zeitwerk via `config.autoload_lib(ignore: %w[assets tasks plugins])`
- `Plugin.bundled_manifests` scans `lib/plugins/*/plugin.yaml`
- Install flow: account installs plugin → files copied to `storage/plugins/<id>/` → agent enables via `AgentPlugin` join
- Two execution modes:
  - `sandbox` — runs command in agent's Docker workspace (e.g. `claude_code`)
  - `platform` — loads `.rb` entrypoint in Rails process, constantizes plugin name to find class (e.g. `web_search` → `WebSearch`)
- Network permissions: `permissions.network` can be `false`, `true`, or array of domains

## Conventions

### Patterns

- **Rich domain models over service objects** — business logic in models, never service classes
- **CRUD controllers** — REST resources; introduce new resources rather than custom actions
- **Concerns for organizing model code** — model-specific in `app/models/<model>/`, shared in `app/models/concerns/`
- **Database-backed everything** — Solid Cache, Solid Queue, Solid Cable (no Redis)
- **Build it yourself before reaching for gems**
- **Vanilla Rails** — maximize what the framework gives you

### Ruby Style

- Method order: class methods → public (`initialize` first) → private
- Order private methods by invocation flow (top-to-bottom)
- No blank line after `private`; indent under it
- `params.expect()` not `params.require().permit()`
- Bang methods (`create!`, `save!`) — let exceptions propagate
- No service objects — use POROs or concerns

### Testing

- **Minitest** (not RSpec), **fixtures** (not FactoryBot)
- Tests ship with features in the same commit
- Test behavior, not implementation
- Integration tests cover full request/response cycles

### Frontend

- Stimulus for JS behavior, Turbo for page updates, importmap for dependencies
- ERB partials (no ViewComponent)
- `data: { turbo_frame: "_top" }` on forms that redirect to a different page

### Do Not Use

Devise, Pundit/CanCanCan, service objects, decorators/presenters, ViewComponent, RSpec, FactoryBot, Sidekiq, GraphQL, Redis.

## Naming

- CLI command: `agentgridos`
- Docker image: `ghcr.io/quantum-fire-labs/agent-grid-os`
- Workspace containers: `agentgridos-workspace-{agent_id}`
- SDK global: `window.AgentGridOS`
- Install dir (production): `/opt/agent-grid-os`

## Docker & CI

- Production image: `ghcr.io/quantum-fire-labs/agent-grid-os:latest` (prebuilt via CI, NOT built on server)
- Workspace image: separate Dockerfile in `docker/workspace/`
- `docker-compose.yml` uses `image:` from GHCR — do NOT switch to `build: .`
- Migrations run automatically via `bin/docker-entrypoint` on container boot
- CI (`.github/workflows/ci.yml`): scan_ruby → scan_js → lint → test → system-test → docker (master only)
- Deploy: push to master → CI builds image → `sudo agentgridos update` on server
