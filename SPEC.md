# Add Network Permission Info to Agent Prompt

## Task
Add network permission info to the agent prompt in `app/models/agent/prompt_builder.rb`.

## What
The agent prompt currently does not inform agents about their network capabilities. The agent model has a `network_mode` enum with values: `none`, `allowed`, `allowed_plus_skills`, `full`. We need to add this info to the system prompt.

## How

1. Add a new private method `network_access` that returns a string based on `agent.network_mode`:

```ruby
def network_access
  case agent.network_mode
  when "none"
    "## Network Access\n\nYou have no network access. You cannot make outbound HTTP requests."
  when "allowed"
    "## Network Access\n\nYou have network access. You can make outbound HTTP requests to external services."
  when "allowed_plus_skills"
    "## Network Access\n\nYou have network access with skill-specific permissions. You can make outbound HTTP requests."
  when "full"
    "## Network Access\n\nYou have full network access. You can make HTTP requests to external services."
  end
end
```

2. Add `parts << network_access` in the `system_prompt` method, after the instructions line and before `skills_instructions`.

## Acceptance Criteria
- [ ] Tests pass (`bin/rails test`)
- [ ] Network access info appears in the agent prompt based on network_mode