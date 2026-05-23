class ProfilesController < ApplicationController
  before_action :authenticate_user!

  def show
    @user = current_user
  end

  def update_password
    @user = current_user

    if @user.update_with_password(password_params)
      bypass_sign_in(@user)
      redirect_to profile_path, notice: 'Пароль успешно изменен'
    else
      redirect_to profile_path, alert: @user.errors.full_messages.to_sentence
    end
  end

  def regenerate_token
    @user = current_user
    @user.update(api_token: SecureRandom.hex(32))

    redirect_to profile_path, notice: 'API токен успешно обновлен'
  end

  private

  def password_params
    params.require(:user).permit(:current_password, :password, :password_confirmation)
  end
end
