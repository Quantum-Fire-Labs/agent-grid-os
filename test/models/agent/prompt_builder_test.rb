require "test_helper"

class Agent::PromptBuilderTest < ActiveSupport::TestCase
  test "includes app tools instructions for agent with own apps" do
    agent = agents(:one)
    prompt = Agent::PromptBuilder.new(agent).system_prompt

    assert_match /App tools/, prompt
    assert_match /app_<slug>_<action>/, prompt
  end

  test "includes granted apps section for agent with granted access" do
    agent = agents(:three) # granted access to slideshow
    prompt = Agent::PromptBuilder.new(agent).system_prompt

    assert_match /Apps you have data access to/, prompt
    assert_match /slideshow/, prompt
    assert_match /App tools/, prompt
  end

  test "granted apps section only lists published apps" do
    agent = agents(:three)
    # Grant access to draft_app too
    CustomAppAgentAccess.create!(agent: agent, custom_app: custom_apps(:draft_app))

    prompt = Agent::PromptBuilder.new(agent).system_prompt

    # slideshow is published, draft_app is draft
    assert_match /slideshow/, prompt
    assert_no_match(/draft-app/, prompt.split("Apps you have data access to").last)
  end

  test "includes enabled skills in prompt" do
    agent = agents(:one) # has code_review skill via fixture
    prompt = Agent::PromptBuilder.new(agent).system_prompt

    assert_match /## Skills/, prompt
    assert_match /Code Review/, prompt
    assert_match /Clear naming conventions/, prompt
  end

  test "excludes skills section when agent has no skills enabled" do
    agent = agents(:three) # no agent_skills fixture
    prompt = Agent::PromptBuilder.new(agent).system_prompt

    assert_no_match(/## Skills/, prompt)
  end

  test "excludes apps section for agent with no apps" do
    agent = Agent.create!(name: "Empty", account: accounts(:one))
    prompt = Agent::PromptBuilder.new(agent).system_prompt

    assert_no_match(/## Apps/, prompt)
    assert_no_match(/App tools/, prompt)
  end
end
