# Claude Code as Provider — Archived Implementation

Removed in favor of keeping Claude Code as a tool-mode plugin only.
This code is saved for potential re-implementation later.

## Overview

Extended the plugin system with a `provider` capability so Claude Code could
serve as the reasoning engine (not just a delegated tool). Plugin declared a
`provider` section in its YAML manifest with models and entrypoint. A MODE
config toggle (tool/provider) controlled behavior per-agent. When MODE=provider,
Brain delegated to the plugin's `chat()` method which streamed Claude Code
output via `workspace.stream_exec()`.

## Plugin::Providable Concern

```ruby
# app/models/plugin/providable.rb
module Plugin::Providable
  extend ActiveSupport::Concern

  def provider?
    provider_config.present?
  end

  def provider_mode?(agent)
    provider? && resolve_config("MODE", agent: agent) == "provider"
  end

  def provider_entrypoint_class
    return nil unless provider?

    entrypoint_file = provider_config["entrypoint"]
    load path.join(entrypoint_file).to_s
    name.classify.constantize
  end
end
```

## ClaudeCode Provider Entrypoint

```ruby
# lib/plugins/claude_code/claude_code.rb
class ClaudeCode
  def initialize(agent:, plugin:)
    @agent = agent
    @plugin = plugin
  end

  def chat(messages:, model: nil, tools: nil, chat: nil, &on_token)
    workspace = Agent::Workspace.new(@agent)

    system_prompt = extract_system_prompt(messages)
    write_system_prompt(workspace, system_prompt) if system_prompt

    last_user = messages.reverse.find { |m| m[:role] == "user" }
    raise Providers::Error, "No user message" unless last_user

    session_id = read_session_id(workspace, chat)
    command = build_command(
      model: model || @plugin.resolve_config("CLAUDE_MODEL", agent: @agent),
      session_id: session_id,
      api_key: @plugin.resolve_config("ANTHROPIC_API_KEY", agent: @agent)
    )

    content = +""
    new_session_id = nil

    workspace.stream_exec(command, stdin: last_user[:content], timeout: 600) do |line|
      event = parse_event(line)
      next unless event

      case event["type"]
      when "system"
        new_session_id = event["session_id"]
      when "assistant"
        if event["content"].present?
          content << event["content"]
          on_token&.call(event["content"])
        end
      when "result"
        new_session_id ||= event["session_id"]
        content = event["result"] if content.blank? && event["result"].present?
      end
    end

    write_session_id(workspace, chat, new_session_id) if chat && new_session_id

    Providers::Response.new(content: content.presence, tool_calls: [], usage: {})
  rescue Agent::Workspace::DockerError => e
    raise Providers::Error, e.message
  end

  private
    def extract_system_prompt(messages)
      first = messages.first
      first[:content] if first && first[:role] == "system"
    end

    def write_system_prompt(workspace, prompt)
      workspace.exec("mkdir -p /home/agent/.claude", timeout: 5)
      workspace.exec("cat > /home/agent/.claude/CLAUDE.md", stdin: prompt, timeout: 5)
    end

    def read_session_id(workspace, chat)
      return nil unless chat
      safe_id = Shellwords.shellescape(chat.id.to_s)
      result = workspace.exec("cat /home/agent/.claude_sessions/#{safe_id} 2>/dev/null", timeout: 5)
      result[:exit_code] == 0 ? result[:stdout].strip.presence : nil
    end

    def build_command(model:, session_id:, api_key:)
      parts = []
      parts << "export ANTHROPIC_API_KEY=#{Shellwords.shellescape(api_key)} &&" if api_key
      parts << "claude -p --verbose --output-format stream-json"
      parts << "--model #{Shellwords.shellescape(model)}" if model.present?
      parts << "-r #{Shellwords.shellescape(session_id)}" if session_id.present?
      parts.join(" ")
    end

    def parse_event(line)
      JSON.parse(line.strip)
    rescue JSON::ParserError
      nil
    end

    def write_session_id(workspace, chat, session_id)
      safe_id = Shellwords.shellescape(chat.id.to_s)
      workspace.exec("mkdir -p /home/agent/.claude_sessions", timeout: 5)
      workspace.exec("cat > /home/agent/.claude_sessions/#{safe_id}", stdin: session_id, timeout: 5)
    end
end
```

## Brain Integration

```ruby
# In Agent::Brain#think, before normal provider dispatch:
if (provider_plugin = agent.plugins.detect { |p| p.provider_mode?(agent) })
  klass = provider_plugin.provider_entrypoint_class
  instance = klass.new(agent: agent, plugin: provider_plugin)
  return instance.chat(
    messages: build_messages,
    model: agent.model,
    chat: chat,
    &on_token
  )
end
```

## PromptBuilder Skip

```ruby
# In Agent::PromptBuilder#plugin_instructions:
next if plugin.provider_mode?(agent)
```

## Plugin YAML Provider Section

```yaml
provider:
  entrypoint: claude_code.rb
  models:
    - id: claude-sonnet-4-6
      name: Claude Sonnet 4.6
    - id: claude-opus-4-6
      name: Claude Opus 4.6
    - id: claude-haiku-4-5
      name: Claude Haiku 4.5

# Additional config entries:
config:
  - key: MODE
    type: select
    options:
      - tool
      - provider
    default: tool
    label: "Mode (tool = agent delegates to Claude Code; provider = Claude Code is the reasoning engine)"
  - key: CLAUDE_MODEL
    type: string
    required: false
    label: "Model for provider mode (e.g. claude-sonnet-4-6)"
```

## Database

```ruby
# Migration: add_column :plugins, :provider_config, :json
# Plugin::Installable: provider_config: manifest["provider"]
```
