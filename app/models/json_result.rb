class JsonResult < ApplicationRecord
  belongs_to :experiment, counter_cache: true

  # Кэширование парсинга JSON - избегаем повторного парсинга
  def parsed_json
    @parsed_json ||= begin
      return metadata if metadata.is_a?(Hash)
      return {} unless metadata.is_a?(String)

      JSON.parse(metadata)
    rescue JSON::ParserError => e
      Rails.logger.error "JSON parsing error for JsonResult #{id}: #{e.message}"
      {}
    end
  end

  # Кэширование статистики для тяжелых вычислений
  def cached_stats
    Rails.cache.fetch([self, "stats", updated_at]) do
      {
        min_fitness: min_fitness,
        max_fitness: max_fitness,
        avg_fitness: avg_fitness,
        total_points: total_points
      }
    end
  end

  def valid_json?
    return false if metadata.nil?
    parsed_json.present?
  end

  %i[dimension comsol_file timestamp].each do |method_name|
    define_method(method_name) { parsed_json[method_name.to_s] }
  end

  def variable_names
    parsed_json['names'] || []
  end

  def best_fitness_history
    parsed_json['best_fitness_history'] || []
  end

  def total_evaluations
    parsed_json['total_evaluations'] || 0
  end

  def method_call
    parsed_json['methodcall']
  end

  def cache_data
    parsed_json['cache'] || {}
  end

  def data_points
    cache_data.map do |key, point_data|
      {
        key: key,
        fitness: point_data['fitness'] || point_data[:fitness],
        values: point_data['values'] || point_data[:values]
      }
    end
  end

  def min_fitness
    fitness_values.min
  end

  def max_fitness
    fitness_values.max
  end

  def avg_fitness
    return nil if fitness_values.empty?
    fitness_values.sum / fitness_values.size.to_f
  end

  def total_points
    data_points.size
  end

  def iterations_count
    best_fitness_history.size
  end

  def variable_ranges
    mins = parsed_json['mins'] || []
    maxs = parsed_json['maxs'] || []
    names = variable_names

    return {} if names.blank? || mins.blank? || maxs.blank?

    names.each_with_index.to_h do |name, i|
      [name, { min: mins[i], max: maxs[i] }]
    end
  end

  alias_method :to_h, :parsed_json
  alias_method :to_hash, :parsed_json

  def as_json(options = {})
    parsed_json.as_json(options)
  end

  private

  def fitness_values
    @fitness_values ||= data_points.map { |p| p[:fitness] }.compact
  end
end
