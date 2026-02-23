class CustomApps::RowsController < ApplicationController
  include AgentAccessible

  before_action :set_custom_app

  def index
    where = params[:where].is_a?(ActionController::Parameters) ? params[:where].to_unsafe_h : nil
    rows = @custom_app.query(
      params[:table_id],
      where: where,
      limit: params[:limit] || 100,
      offset: params[:offset] || 0
    )
    render json: { rows: rows }
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def show
    row = @custom_app.get_row(params[:table_id], params[:row_id])
    if row
      render json: { row: row }
    else
      head :not_found
    end
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def create
    data = params[:data].is_a?(ActionController::Parameters) ? params[:data].to_unsafe_h : {}
    row_id = @custom_app.insert_row(params[:table_id], data)
    render json: { id: row_id }, status: :created
  rescue ArgumentError, RuntimeError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def update
    data = params[:data].is_a?(ActionController::Parameters) ? params[:data].to_unsafe_h : {}
    changes = @custom_app.update_row(params[:table_id], params[:row_id], data)
    if changes > 0
      render json: { updated: changes }
    else
      head :not_found
    end
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def destroy
    changes = @custom_app.delete_row(params[:table_id], params[:row_id])
    if changes > 0
      head :no_content
    else
      head :not_found
    end
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private
    def set_custom_app
      @custom_app = accessible_custom_apps.published.find(params[:custom_app_id])
    end
end
