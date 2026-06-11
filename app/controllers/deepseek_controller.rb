class DeepseekController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:analyze_experiment]

  def analyze_experiment
    experiment = Experiment.find_by(id: params[:experiment_id])

    if experiment.nil?
      render json: { error: "Experiment not found" }, status: 404
      return
    end

    json_result = experiment.json_results.order(created_at: :desc).first

    if json_result.nil? || json_result.metadata.blank?
      render json: { error: "No data found" }, status: 404
      return
    end

    connection_id = SecureRandom.uuid

    DeepseekAnalysisJob.perform_later(
      params[:experiment_id],
      params[:query],
      current_user&.id,
      connection_id
    )

    render json: {
      status: "processing",
      connection_id: connection_id,
      message: "Анализ запущен в фоновом режиме"
    }
  end
end
