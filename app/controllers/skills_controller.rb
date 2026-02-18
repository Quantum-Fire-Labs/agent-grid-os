class SkillsController < ApplicationController
  before_action :require_admin

  def index
    @skills = Current.account.skills
  end

  def show
    @skill = Current.account.skills.find(params[:id])
  end

  def new
    @skill = Skill.new
  end

  def create
    @skill = Current.account.skills.build(skill_params)

    if @skill.save
      redirect_to @skill, notice: "Skill created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @skill = Current.account.skills.find(params[:id])
  end

  def update
    @skill = Current.account.skills.find(params[:id])

    if @skill.update(skill_params)
      redirect_to @skill, notice: "Skill updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @skill = Current.account.skills.find(params[:id])
    @skill.destroy
    redirect_to skills_path, notice: "#{@skill.name} has been deleted."
  end

  private
    def skill_params
      params.expect(skill: [ :name, :description, :body ])
    end
end
