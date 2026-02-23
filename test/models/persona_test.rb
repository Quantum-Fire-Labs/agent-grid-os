require "test_helper"

class PersonaTest < ActiveSupport::TestCase
  test "all returns a list of personas" do
    personas = Persona.all
    assert_kind_of Array, personas
    assert personas.any?, "expected at least one bundled persona"
    assert personas.all? { |p| p.is_a?(Persona) }
  end

  test "find returns persona by name" do
    persona = Persona.find("the_orchestrator")
    assert_kind_of Persona, persona
    assert_equal "the_orchestrator", persona.name
  end

  test "find raises NotFound for unknown name" do
    assert_raises(Persona::NotFound) do
      Persona.find("nonexistent_persona")
    end
  end

  test "persona exposes expected attributes" do
    persona = Persona.find("the_orchestrator")
    assert_equal "The Orchestrator", persona.title
    assert persona.description.present?
    assert persona.personality.present?
    assert persona.instructions.present?
  end

  test "network_mode defaults to none when not set" do
    persona = Persona.find("the_orchestrator")
    assert_equal "none", persona.network_mode
  end

  test "workspace_enabled defaults to false when not set" do
    persona = Persona.find("the_orchestrator")
    assert_equal false, persona.workspace_enabled
  end

  test "recommended_plugins defaults to empty array" do
    persona = Persona.find("the_orchestrator")
    assert_equal [], persona.recommended_plugins
  end

  test "recommended_settings returns a hash" do
    persona = Persona.find("the_orchestrator")
    assert_kind_of Hash, persona.recommended_settings
  end

  test "agent_attributes returns hash with required keys" do
    persona = Persona.find("the_orchestrator")
    attrs = persona.agent_attributes

    assert_kind_of Hash, attrs
    assert_includes attrs.keys, :title
    assert_includes attrs.keys, :description
    assert_includes attrs.keys, :personality
    assert_includes attrs.keys, :instructions
    assert_includes attrs.keys, :network_mode
    assert_includes attrs.keys, :workspace_enabled
  end

  test "agent_attributes values match persona fields" do
    persona = Persona.find("the_orchestrator")
    attrs = persona.agent_attributes

    assert_equal persona.title, attrs[:title]
    assert_equal persona.description, attrs[:description]
    assert_equal persona.personality, attrs[:personality]
    assert_equal persona.instructions, attrs[:instructions]
    assert_equal persona.network_mode, attrs[:network_mode]
    assert_equal persona.workspace_enabled, attrs[:workspace_enabled]
  end

  test "agent_attributes includes recommended_settings" do
    persona = Persona.find("the_orchestrator")
    attrs = persona.agent_attributes

    assert_equal true, attrs[:orchestrator]
  end
end
