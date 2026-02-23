class CustomApps::UsersController < ApplicationController
  before_action :require_admin
  before_action :set_custom_app

  def create
    user = Current.account.users.find(params[:user_id])
    @custom_app.custom_app_users.create!(user: user)
    redirect_to custom_app_settings_path(@custom_app), notice: "#{user.first_name} added."
  end

  def destroy
    custom_app_user = @custom_app.custom_app_users.find(params[:id])
    name = custom_app_user.user.first_name
    custom_app_user.destroy
    redirect_to custom_app_settings_path(@custom_app), notice: "#{name} removed."
  end

  private
    def set_custom_app
      @custom_app = Current.account.custom_apps.find(params[:custom_app_id])
    end
end
