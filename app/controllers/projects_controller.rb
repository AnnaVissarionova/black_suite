class ProjectsController < ApplicationController
  include ExperimentsHelper

  before_action :set_project, only: %i[show edit update destroy update_sharing disable_sharing regenerate_token sharing show_experiment]

  skip_before_action :verify_authenticity_token, only: [:api_add_experiment_result]
  skip_before_action :authenticate_user_or_check_shared_access!, only: [:api_add_experiment_result]

  def index
    redirect_to new_user_session_path, alert: 'Необходимо войти в систему' and return unless current_user

    @projects = current_user.projects
                            .select(:id, :name, :description, :created_at, :experiments_count)
                            .order(created_at: :desc)
  end

  def show
    if params[:share_token].present?
      @project = Project.find_by(share_token: params[:share_token])
      unless @project&.shared?
        redirect_to root_path, alert: 'Проект не найден или доступ ограничен'
        return
      end
      @experiments = @project.experiments
                             .select(:id, :name, :description, :created_at, :project_id)
                             .order(created_at: :desc)
      render :show
      return
    end

    authorize @project
    @experiments = @project.experiments
                           .select(:id, :name, :description, :created_at, :project_id)
                           .order(created_at: :desc)
  end

  def show_experiment
    if params[:share_token].present?
      @project = Project.find_by(share_token: params[:share_token])
      unless @project&.shared?
        render plain: 'Access denied', status: :unauthorized
        return
      end

      if params[:experiment_id].present?
        @experiment = @project.experiments.find(params[:experiment_id])
      else
        @experiment = @project.experiments.find_by(share_token: params[:share_token])
      end

      @experiments = @project.experiments
                             .select(:id, :name, :description, :created_at, :project_id)
                             .order(created_at: :desc)
    else
      authorize @project
      @experiment = @project.experiments
                            .includes(:json_results)
                            .find(params[:experiment_id])
      authorize @experiment, :show?
    end

    @latest_json = @experiment.json_results.max_by(&:created_at)
    @json_results_count = @experiment.json_results_count

    if @latest_json&.valid_json?
      @stats = extract_stats(@latest_json, param_x, param_y)
      @plot_3d_data = @stats[:plot_3d_data]
      @fitness_history_data = @stats[:fitness_history_data]

      @plot_3d_data ||= { points: [], selected_x_name: 'X', selected_y_name: 'Y' }
      @fitness_history_data ||= { history: [], iterations: [] }
    else
      @plot_3d_data = { points: [], selected_x_name: 'X', selected_y_name: 'Y' }
      @fitness_history_data = { history: [], iterations: [] }
    end

    if request.xhr? || params[:partial] == 'true'
      render partial: 'experiments/experiment_partial', layout: false
    else
      render 'experiments/show'
    end
  end

  def new
    redirect_to new_user_session_path, alert: 'Необходимо войти в систему' and return unless current_user
    @project = current_user.projects.new
    authorize @project
  end

  def edit
    authorize @project
  end

  def create
    redirect_to new_user_session_path, alert: 'Необходимо войти в систему' and return unless current_user
    @project = current_user.projects.new(project_params)
    authorize @project

    if @project.save
      redirect_to projects_path, notice: 'Проект успешно создан'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    authorize @project
    if @project.update(project_params)
      redirect_to projects_path, notice: 'Проект успешно обновлён'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @project
    project_name = @project.name
    @project.destroy
    redirect_to projects_url, notice: "Проект «#{project_name}» удалён"
  end

  def update_sharing
    authorize @project, :update?
    begin
      case params[:share_mode]
      when 'view'
        if @project.share_mode == 'view' && @project.share_token.present?
          render json: {
            success: true,
            message: 'Доступ уже включен',
            shared: true,
            share_mode: 'view',
            share_token: @project.share_token,
            share_url: shared_project_url(@project.share_token)
          }
        else
          token = generate_unique_token

          @project.update!(
            share_mode: 'view',
            share_token: token
          )

          render json: {
            success: true,
            message: 'Ссылка для доступа создана',
            shared: true,
            share_mode: 'view',
            share_token: @project.share_token,
            share_url: shared_project_url(@project.share_token)
          }
        end

      when 'private'
        @project.update!(
          share_mode: 'private',
          share_token: nil
        )

        render json: {
          success: true,
          message: 'Доступ по ссылке отключён',
          shared: false,
          share_mode: 'private'
        }

      else
        render json: {
          success: false,
          error: 'Неверный режим доступа'
        }, status: :unprocessable_entity
      end

    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "Validation error: #{e.message}"
      render json: {
        success: false,
        error: "Ошибка валидации: #{e.message}",
        errors: @project.errors.full_messages
      }, status: :unprocessable_entity

    rescue => e
      Rails.logger.error "Unexpected error: #{e.message}"
      render json: {
        success: false,
        error: "Внутренняя ошибка: #{e.message}"
      }, status: :internal_server_error
    end
  end

  def sharing
    authorize @project, :update?

    render json: {
      shared: @project.shared?,
      share_mode: @project.share_mode,
      share_token: @project.share_token,
      share_url: @project.shared? ? shared_project_url(@project.share_token) : nil
    }
  end

  def regenerate_token
    authorize @project, :update?

    begin
      if @project.share_mode != 'view'
        render json: {
          success: false,
          error: 'Доступ по ссылке не включен'
        }, status: :unprocessable_entity
        return
      end

      @project.regenerate_share_token!

      render json: {
        success: true,
        message: 'Ссылка для доступа обновлена',
        shared: true,
        share_mode: 'view',
        share_token: @project.share_token,
        share_url: shared_project_url(@project.share_token)
      }

    rescue => e
      Rails.logger.error "Error in regenerate_token: #{e.message}"
      render json: {
        success: false,
        error: "Ошибка при обновлении ссылки: #{e.message}"
      }, status: :internal_server_error
    end
  end


  def disable_sharing
    authorize @project, :update?

    begin
      @project.disable_sharing!
      render json: {
        success: true,
        message: 'Доступ по ссылке отключён',
        shared: false
      }
    rescue => e
      Rails.logger.error "Error disabling project sharing: #{e.message}"
      render json: {
        success: false,
        error: "Ошибка при отключении доступа: #{e.message}"
      }, status: :unprocessable_entity
    end
  end

  def api_add_experiment_result
    authenticate_with_api_token!
    return if performed?


    unless params[:project_id].present? && params[:json_file].present?
      render json: {
        success: false,
        error: 'Missing required parameters: project_id, json_file'
      }, status: :bad_request
      return
    end

    project = @current_user.projects.find_by(id: params[:project_id])
    unless project
      render json: {
        success: false,
        error: 'Project not found'
      }, status: :not_found
      return
    end

    experiment_name = params[:experiment_name].presence || 'Эксперимент без названия'
    experiment = project.experiments.create!(
      name: experiment_name,
      description: "Автоматически создан через API \n #{Time.current}"
    )

    # Парсим JSON
    begin
      json_data = JSON.parse(params[:json_file].read)
    rescue JSON::ParserError => e
      render json: {
        success: false,
        error: "Invalid JSON format: #{e.message}"
      }, status: :bad_request
      return
    end

    # Сохраняем результат
    json_result = JsonResult.create!(
      experiment: experiment,
      metadata: json_data
    )

    render json: {
      success: true,
      message: 'Experiment result added successfully',
      data: {
        experiment_id: experiment.id,
        experiment_name: experiment.name,
        json_result_id: json_result.id
      }
    }, status: :created

  rescue => e
    render json: {
      success: false,
      error: e.message
    }, status: :internal_server_error
  end

  private

  def generate_unique_token
    loop do
      token = SecureRandom.urlsafe_base64(16)
      break token unless Project.exists?(share_token: token)
    end
  end

  def set_project
    if params[:share_token].present?
      @project = Project.includes(
        experiments: [:json_results]
      ).find_by!(share_token: params[:share_token])

    elsif current_user.present?
      if action_name == 'show_experiment'
        @project = current_user.projects.find(params[:id])
      else
        @project = current_user.projects
                              .includes(:experiments)
                              .find(params[:id])
      end
    else
      redirect_to new_user_session_path, alert: 'Необходимо войти в систему'
    end
  end

  def project_params
    params.require(:project).permit(:name, :description)
  end

  def param_x
    params[:param_x]&.to_i || 0
  end

  def param_y
    params[:param_y]&.to_i || 1
  end

  def shared
    @project = Project.find_by(share_token: params[:share_token])

    if @project && @project.share_mode == 'view'
      @experiments = @project.experiments.order(created_at: :desc)
      render :show
    else
      redirect_to root_path, alert: 'Проект не найден или доступ ограничен'
    end
  end

  def authenticate_with_api_token!
    @current_user = User.find_by(api_token: 'a054ba540a3863328505872bee7580b26e4b7ade44391cc66b34ca86fcd2c553')
    api_token = request.headers['Authorization']&.gsub(/Bearer\s+/, '')

    Rails.logger.info "API Token received: #{api_token.inspect}"

    if api_token.blank?
      render json: { success: false, error: 'API token required' }, status: :unauthorized
      return
    end

    @current_user = User.find_by(api_token: api_token)

    Rails.logger.info "User found: #{@current_user.inspect}"

    unless @current_user
      render json: { success: false, error: 'Invalid API token' }, status: :unauthorized
      return
    end


  end
end
