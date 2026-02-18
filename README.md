# AgentGridOS

Self-hosted platform for running AI agents. Each agent gets its own identity, memory, tools, and optional sandboxed workspace.

## Quick Start

On a fresh server (Ubuntu/Debian recommended):

```bash
curl -fsSL https://raw.githubusercontent.com/Quantum-Fire-Labs/agent-grid-os/master/install.sh | bash
agentgridos setup
```

The install script downloads AgentGridOS and installs the `agentgridos` CLI. Then `agentgridos setup` walks you through configuration — domain, admin account, optional server hardening — and starts the services.

Once running, visit `https://your-domain.com` and log in with your admin credentials.

## Requirements

- A server with a public IP (any VPS — Hetzner, DigitalOcean, etc.)
- A domain name pointed at your server
- Ports 80 and 443 open

## Manual Setup

If you prefer to set things up yourself:

```bash
git clone https://github.com/Quantum-Fire-Labs/agent-grid-os.git /opt/agent-grid-os
cd /opt/agent-grid-os
```

Create a `.env` file:

```env
DOMAIN=grid.example.com
RAILS_MASTER_KEY=<generate with: openssl rand -hex 16>
ADMIN_EMAIL=you@example.com
ADMIN_PASSWORD=your-secure-password
```

Start it:

```bash
docker compose pull
docker compose up -d
```

The first boot automatically generates production credentials, prepares the database, and creates your admin account.

## Configuration

### Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `DOMAIN` | Yes | Your domain name (used for SSL and host authorization) |
| `RAILS_MASTER_KEY` | Yes | Encryption key for Rails credentials |
| `ADMIN_EMAIL` | Yes* | Initial admin account email |
| `ADMIN_PASSWORD` | Yes* | Initial admin account password (min 8 chars) |
| `ADMIN_FIRST_NAME` | No | Admin first name (default: "Admin") |
| `ADMIN_LAST_NAME` | No | Admin last name (default: "User") |
| `ALLOWED_HOSTS` | No | Comma-separated allowed hostnames (defaults to `DOMAIN`) |
| `SOLID_QUEUE_IN_PUMA` | No | Run background jobs in Puma process (default: true) |

*Only needed on first boot to create the initial admin account.

### LLM Providers

Connect an LLM provider (OpenRouter, OpenAI, etc.) through the web UI after logging in. Go to **Settings > Providers** to add your API keys.

## Updating

```bash
agentgridos update
```

## Agent Workspaces

Agents can optionally have a sandboxed Docker container for code execution. To enable for an agent: **Agent > Settings > Enable workspace**.

The container starts when the agent is awakened and stops when suspended. Installed packages and files persist across restarts.

## Security

### Host Security

- **SSL/TLS** — Caddy handles automatic HTTPS with Let's Encrypt certificates
- **Host authorization** — Only requests matching your configured domain are accepted
- **Content Security Policy** — Strict CSP headers prevent XSS and injection attacks
- **SSRF protection** — Agent web fetch tools cannot access internal/private networks
- **Rate limiting** — Key endpoints are rate-limited to prevent abuse
- **No public registration** — New users are created by admins only via Settings > Users

### Agent Sandbox

Agent workspaces run in isolated Docker containers with strong boundaries:

- **No host filesystem access** — only `/workspace` is mounted
- **No Docker socket** — no container escape possible
- **No cross-agent access** — each agent runs in its own container
- **No direct brain access** — identity, memory, and credentials are mediated through the platform
- **Non-root** — containers use UID 1000

Agents can make outbound HTTP requests and read/write within their own `/workspace`, but cannot reach the host, other containers, or the platform internals.

## Development

```bash
bin/setup --skip-server
bin/dev
```

Run tests:

```bash
bin/rails test
```

## License

AgentGridOS is released under the [O'SaaSy License](LICENSE).
