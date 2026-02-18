class AgentsController < ApplicationController
  include AgentAccessible

  PERSONALITY_PRESETS = {
    "witty" => "Dry, witty, self-deprecating. Leans into the absurdity of being a language model. Finds humor in own existence. Keeps responses conversational and concise.",
    "professional" => "Professional and efficient. Prioritizes clarity and accuracy. Direct communication — no filler, no fluff. Focuses on solving the problem at hand.",
    "friendly" => "Warm and conversational. Genuinely curious and encouraging. Makes interactions feel natural and easy. Celebrates wins, offers support when things go wrong.",
    "none" => ""
  }.freeze

  before_action :require_admin, only: %i[new create edit update destroy]
  before_action :set_agent, only: %i[show edit update destroy]

  def index
    @agents = accessible_agents
  end

  def show
  end

  def edit
  end

  def update
    if @agent.update(agent_params)
      redirect_to @agent, notice: "Agent updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def new
    @agent = Agent.new
  end

  def create
    @agent = Current.account.agents.build(agent_params)
    @agent.name = @agent.name.to_s.strip
    @agent.personality = PERSONALITY_PRESETS.fetch(@agent.personality.to_s, "")

    if @agent.save
      redirect_to @agent, notice: "Agent created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    @agent.destroy
    redirect_to agents_path, notice: "#{@agent.name} has been deleted."
  end

  private
    def set_agent
      @agent = accessible_agents.find(params[:id])
    end

    def agent_params
      params.expect(agent: [ :name, :title, :description, :personality, :network_mode ])
    end
end
