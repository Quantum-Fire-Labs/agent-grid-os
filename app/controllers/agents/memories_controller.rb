class Agents::MemoriesController < ApplicationController
  before_action :require_admin
  before_action :set_agent
  before_action :set_memory, only: %i[edit update destroy]

  def index
    @memories = @agent.memories.order(created_at: :desc)
    @memories = @memories.where("content LIKE ?", "%#{sanitize_sql_like(params[:q])}%") if params[:q].present?
    @memories = @memories.load
  end

  def edit
  end

  def update
    @memory.update!(memory_params)
    redirect_to agent_memories_path(@agent), notice: "Memory updated."
  end

  def destroy
    @memory.destroy!
    redirect_to agent_memories_path(@agent), notice: "Memory deleted."
  end

  private
    def set_agent
      @agent = Current.account.agents.find(params[:agent_id])
    end

    def set_memory
      @memory = @agent.memories.find(params[:id])
    end

    def memory_params
      params.expect(memory: [ :content ])
    end
end
