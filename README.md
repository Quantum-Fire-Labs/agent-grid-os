# TheGrid

Self-hosted platform for running AI agents. Each agent gets its own identity, memory, tools, and optional sandboxed workspace.

## Requirements

- Ruby 4.0.1
- SQLite 3
- Docker (for agent workspaces)
- Node.js (for asset pipeline)

## Setup

```bash
git clone <repo-url> thegrid && cd thegrid

# Install Ruby deps, prepare DB, build workspace image
bin/setup --skip-server

# Or step by step:
bundle install
bin/rails db:prepare
docker build -t thegrid-workspace:latest docker/workspace/
```

## Configuration

Generate your master key and credentials:

```bash
bin/rails credentials:edit
```

Connect an LLM provider (OpenRouter, OpenAI, etc.) through the web UI after first login.

## Running

```bash
# Development
bin/dev

# Production
bin/rails server -e production
```

## Agent Workspaces

Agents can optionally have a sandboxed Docker container for code execution. The workspace image is shared across all agents — you build it once during setup.

To enable for an agent: **Agent > Settings > Enable workspace**

The container starts when the agent is awakened and stops when suspended. Installed packages and files persist across restarts.

To rebuild the workspace image (e.g. after updating the Dockerfile):

```bash
docker build -t thegrid-workspace:latest docker/workspace/
```

## Security Model

Agent workspaces run in isolated Docker containers with strong boundaries between the sandbox and your host machine.

**What agents can't do:**

- Access your host filesystem — only `/workspace` is mounted
- Access the Docker socket — no container escape possible
- Reach other agents' workspaces — each runs in its own container
- Directly read their own brain files (identity, memory, credentials) — all mediated through the platform
- Run as root — containers use a non-root user (UID 1000)

**What agents can do with full network access:**

- Make outbound HTTP requests (curl, wget, etc.) from within their sandbox
- Download and run code inside their container
- Read/write anything in their own `/workspace`

**Trust boundary:** The Rails app is the trusted platform layer. It manages agent processes, holds API keys, and mediates all access to brain files and credentials. Agent code runs in untrusted sandboxes with no path back to the platform or host.

**Bottom line:** Running locally is safe. Even with full internet access, an agent is stuck inside its Docker sandbox with only its workspace. It cannot touch your local files, other containers, or escalate privileges.

## Tests

```bash
bin/rails test
```

## Deployment

Build the production Docker image:

```bash
docker build -t thegrid .
docker run -d -p 80:80 -e RAILS_MASTER_KEY=<value from config/master.key> thegrid
```

Or deploy with [Kamal](https://kamal-deploy.org):

```bash
bin/kamal deploy
```

## License

[OSAASy](https://osaasy.dev/) — free to use, modify, and distribute. The only restriction is you can't offer it as a competing hosted/SaaS product.
