class Settings::UsersController < ApplicationController
  before_action :require_admin, only: %i[new create edit update destroy]
  before_action :set_user, only: %i[show edit update destroy]

  def index
    @users = Current.account.users.order(:created_at)
  end

  def show
  end

  def new
    @user = Current.account.users.new
  end

  def create
    @user = Current.account.users.new(user_params)

    if @user.save
      redirect_to settings_user_path(@user), notice: "User added."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    filtered = user_params
    filtered = filtered.except(:password, :password_confirmation) if filtered[:password].blank?

    if @user.update(filtered)
      redirect_to settings_user_path(@user), notice: "User updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @user == Current.user
      redirect_to settings_users_path, alert: "You can't delete yourself."
    else
      @user.destroy
      redirect_to settings_users_path, notice: "User removed."
    end
  end

  private
    def set_user
      @user = Current.account.users.find(params[:id])
    end

    def user_params
      params.expect(user: [ :first_name, :last_name, :email_address, :password, :password_confirmation, :role ])
    end
end
