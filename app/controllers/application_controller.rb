class ApplicationController < ActionController::Base
  include Pundit::Authorization
  before_action :authenticate_user_or_check_shared_access!
  before_action :configure_permitted_parameters, if: :devise_controller?

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:email, :password, :password_confirmation])
    devise_parameter_sanitizer.permit(:account_update, keys: [:email])
  end

  def after_sign_in_path_for(resource)
    set_flash_message!(:notice, :signed_in)
    projects_path
  end

  def after_sign_out_path_for(resource_or_scope)
    set_flash_message!(:notice, :signed_out) if signed_in_root_path(resource_or_scope)
    new_user_session_path
  end

  def after_sign_up_path_for(resource)
    set_flash_message!(:notice, :signed_up)
    projects_path
  end

  def after_update_path_for(resource)
    set_flash_message!(:notice, :updated)
    edit_user_registration_path
  end


  def current_user
    return @_current_user if defined?(@_current_user)

    @_current_user = warden.authenticate(scope: :user)
  end

  def authenticate_user_or_check_shared_access!
    return if user_signed_in?
    return if devise_controller?

    if params[:share_token].present?
      if params[:controller].include?('projects')
        @shared_project = Project.find_by(share_token: params[:share_token])
        return if @shared_project&.shared?
      elsif params[:controller].include?('experiments')
        @shared_experiment = Experiment.find_by(share_token: params[:share_token])
        return if @shared_experiment&.shared?
      end
    end

    authenticate_user!
  end

  def user_not_authorized
    flash[:alert] = 'У вас нет доступа к этой странице'
    redirect_to(request.referrer || root_path)
  end

  def user_signed_in?
    current_user.present?
  end
end
