class CustomApps::TablesController < ApplicationController
  include AgentAccessible

  before_action :set_custom_app

  def index
    tables = @custom_app.list_tables
    render json: { tables: tables }
  end

  def create
    name = params[:name]
    columns = params[:columns]

    return render json: { error: "name is required" }, status: :unprocessable_entity if name.blank?
    return render json: { error: "columns are required" }, status: :unprocessable_entity if columns.blank?

    @custom_app.create_table(name, columns)
    render json: { table: name }, status: :created
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def destroy
    @custom_app.drop_table(params[:id])
    head :no_content
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private
    def set_custom_app
      @custom_app = CustomApp.published.where(agent: accessible_agents).find(params[:custom_app_id])
    end
end
