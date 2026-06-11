class ExperimentsController < ApplicationController
  include ExperimentsHelper

  before_action :set_project
  before_action :set_experiment, only: %i[show edit update destroy download_json update_sharing regenerate_token sharing]

  def index
    @experiments = @project.experiments
                           .select_for_list
                           .ordered_by_created
                           .then { |scope| apply_filters(scope) }
                           .then { |scope| apply_sorting(scope) }
  end

  def show
    if params[:share_token].present?
      authorize @experiment
      @latest_json = @experiment.json_results.order(created_at: :desc).first
      @json_results_count = @experiment.json_results_count

      if @latest_json&.valid_json?
        @stats = extract_stats(@latest_json, param_x, param_y)
        @plot_3d_data = @stats[:plot_3d_data]
        @fitness_history_data = @stats[:fitness_history_data]
      end
      return
    end

    redirect_to experiment_view_project_path(@project, experiment_id: @experiment.id, param_x: params[:param_x], param_y: params[:param_y])
  end

  def new
    @experiment = @project.experiments.new
    authorize @experiment
  end

  def edit
    authorize @experiment
  end

  def update
    authorize @experiment
    if @experiment.update(experiment_params)
      if params[:json_file].present?
        begin
          json_data = JSON.parse(params[:json_file].read)
          JsonResult.create!(experiment: @experiment, metadata: json_data)
        rescue JSON::ParserError => e
          flash[:alert] = "Ошибка при обработке JSON файла: #{e.message}"
        end
      end
      redirect_to project_path(@project), notice: 'Эксперимент успешно обновлён'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def create
    @experiment = @project.experiments.new(experiment_params)
    authorize @experiment

    if @experiment.save
      create_json_result if json_file_present?
      redirect_to project_path(@project), notice: 'Эксперимент успешно создан'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @experiment
    experiment_name = @experiment.name
    @experiment.destroy
    redirect_to project_path(@project), notice: "Эксперимент «#{experiment_name}» удалён"
  end

  def download_json
    authorize @experiment

    @latest_json = @experiment.json_results.order(created_at: :desc).first

    if @latest_json && @latest_json.metadata.present?
      json_content = @latest_json.metadata.is_a?(String) ? @latest_json.metadata : @latest_json.metadata.to_json

      send_data json_content,
                filename: "#{@experiment.name.parameterize}_results.json",
                type: 'application/json',
                disposition: 'attachment'
    else
      redirect_to project_path(@project),
                  alert: 'JSON файл не найден'
    end
  end

  def update_sharing
    authorize @experiment, :manage_sharing?

    if params[:enable_sharing] == 'true'
      @experiment.regenerate_share_token! unless @experiment.shared?
      render json: {
        success: true,
        shared: true,
        share_token: @experiment.share_token,
        share_url: shared_experiment_url(@experiment.share_token)
      }
    else
      @experiment.disable_sharing!
      render json: {
        success: true,
        shared: false
      }
    end
  end

  def regenerate_token
    authorize @experiment, :manage_sharing?

    @experiment.regenerate_share_token!
    render json: {
      success: true,
      shared: true,
      share_token: @experiment.share_token,
      share_url: shared_experiment_url(@experiment.share_token)
    }
  end

  def sharing
    authorize @experiment, :manage_sharing?

    render json: {
      shared: @experiment.shared?,
      share_token: @experiment.share_token,
      share_url: @experiment.shared? ? shared_experiment_url(@experiment.share_token) : nil
    }
  end

  def update_plot_data
    @experiment = @project.experiments.includes(:json_results).find(params[:id])
    authorize @experiment, :show?

    @latest_json = @experiment.json_results.max_by(&:created_at)

    if @latest_json&.valid_json?
      @stats = extract_stats(@latest_json, params[:param_x]&.to_i || 0, params[:param_y]&.to_i || 1)
      plot_3d_data = @stats[:plot_3d_data]
      fitness_history_data = @stats[:fitness_history_data]
    end

    render json: {
      plot_3d: plot_3d_data || {},
      fitness_history: fitness_history_data || {}
    }
  end

  private

  def set_project
    if params[:share_token].present?
      @experiment = Experiment.includes(:project, :json_results).find_by(share_token: params[:share_token])
      if @experiment
        @project = @experiment.project
        return
      else
        @project = Project.find_by(share_token: params[:share_token])
        if @project
          render 'projects/show' and return
        else
          redirect_to root_path, alert: 'Ресурс не найден'
          return
        end
      end
    end

    if current_user
      @project = current_user.projects.find_by(id: params[:project_id])
      unless @project
        redirect_to projects_path, alert: 'Проект не найден'
        return
      end
    else
      redirect_to new_user_session_path, alert: 'Необходимо войти в систему'
    end
  end

  def set_experiment
    if params[:share_token].present?
      @experiment = Experiment.includes(:json_results).find_by!(share_token: params[:share_token])
    else
      @experiment = @project.experiments.find(params[:id])
    end
  end

  def experiment_params
    params.require(:experiment).permit(:name, :description, :json_file)
  end

  def apply_filters(scope)
    scope = scope.where(status: params[:status]) if params[:status].present?
    scope = scope.where('name ILIKE ? OR description ILIKE ?', "%#{params[:search]}%", "%#{params[:search]}%") if params[:search].present?
    scope
  end

  def apply_sorting(scope)
    case params[:sort]
    when 'created_at_asc' then scope.order(created_at: :asc)
    when 'name_asc' then scope.order(name: :asc)
    when 'name_desc' then scope.order(name: :desc)
    else scope.order(created_at: :desc)
    end
  end

  def param_x
    params[:param_x]&.to_i || 0
  end

  def param_y
    params[:param_y]&.to_i || 1
  end

  def json_file_present?
    params[:experiment][:json_file].present?
  end

  def create_json_result
    json_data = JSON.parse(params[:experiment][:json_file].read) rescue {}
    JsonResult.create!(experiment: @experiment, metadata: json_data)
  end
end
