class Settings::AccountsController < ApplicationController
  before_action :require_admin

  def show
  end

  def update
    if Current.account.update(account_params)
      redirect_to settings_account_path, notice: "Account updated."
    else
      render :show, status: :unprocessable_entity
    end
  end

  private
    def account_params
      params.expect(account: [ :name ])
    end
end
