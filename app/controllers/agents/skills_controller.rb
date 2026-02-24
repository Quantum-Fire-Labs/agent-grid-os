class Agents::SkillsController < ApplicationController
  include AgentAccessible

  before_action :set_agent
  before_action :require_agent_admin

  def index
    @enabled_skills = @agent.skills
    @agent_skills_by_skill_id = @agent.agent_skills.index_by(&:skill_id)
    @available_skills = Current.account.skills.where.not(id: @agent.skill_ids)
  end

  def create
    skill = Current.account.skills.find(params[:skill_id])
    @agent.agent_skills.create!(skill: skill)
    redirect_to agent_skills_path(@agent), notice: "#{skill.name} enabled."
  end

  def destroy
    agent_skill = @agent.agent_skills.find(params[:id])
    name = agent_skill.skill.name
    agent_skill.destroy
    redirect_to agent_skills_path(@agent), notice: "#{name} disabled."
  end

  private
    def set_agent
      @agent = accessible_agents.find(params[:agent_id])
    end
end
