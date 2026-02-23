class CustomApps::SettingsController < ApplicationController
  before_action :require_admin

  def show
    @custom_app = Current.account.custom_apps.find(params[:custom_app_id])
    @custom_app_users = @custom_app.custom_app_users.includes(:user).order("users.first_name")
    @available_users = Current.account.users.where.not(id: @custom_app.user_ids).order(:first_name)
  end
end
