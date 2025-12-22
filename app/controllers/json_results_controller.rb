class JsonResultsController < ApplicationController
  before_action :set_project
  before_action :set_experiment
  before_action :set_json_result, only: [:show, :destroy, :download]

  def show
    @json_content = @json_result.parsed_json
  end

  def new
    @json_result = @experiment.json_results.new
  end

  def create
    @json_result = @experiment.json_results.new(json_result_params)

    if @json_result.save
      redirect_to project_experiment_json_result_path(@project, @experiment, @json_result),
                  notice: 'JSON успешно создан.'
    else
      render :new
    end
  end

  def destroy
    @json_result.destroy
    redirect_to project_experiment_path(@project, @experiment),
                notice: 'JSON успешно удален.'
  end

  def download
    if @json_result.json_file.attached?
      send_data @json_result.json_file.download,
                filename: @json_result.json_file.filename.to_s,
                type: @json_result.json_file.content_type,
                disposition: 'attachment'
    else
      redirect_to project_experiment_path(@project, @experiment),
                  alert: 'Файл не найден.'
    end
  end

  private

  def set_project
    @project = current_user.projects.find(params[:project_id])
  end

  def set_experiment
    @experiment = @project.experiments.find(params[:experiment_id])
  end

  def set_json_result
    @json_result = @experiment.json_results.find(params[:id])
  end

  def json_result_params
    params.require(:json_result).permit(:title, :description, :json_file)
  end
end