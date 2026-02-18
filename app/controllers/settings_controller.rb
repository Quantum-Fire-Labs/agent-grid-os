class SettingsController < ApplicationController
  def show
    redirect_to settings_profile_path
  end
end
