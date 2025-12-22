module ExperimentsHelper
  def extract_stats(json_result, selected_x_index = 0, selected_y_index = 1)
    data = json_result.parsed_json
    cache = data['cache'] || {}
    names = data['names'] || []
    history = data['best_fitness_history'] || []

    points = cache.map do |_, point_data|
      values = point_data['values']
      fitness = point_data['fitness']
      {
        x: values[selected_x_index],
        y: values[selected_y_index],
        z: fitness,
        values: values,
        fitness: fitness
      }
    end

    fitness_values = points.map { |p| p[:z] }.compact

    min_fitness = fitness_values.min
    max_fitness = fitness_values.max
    avg_fitness = fitness_values.empty? ? 0 : fitness_values.sum / fitness_values.size.to_f

    best_point = if fitness_values.empty?
      { values: [], fitness: nil }
    else
      bp = points.min_by { |p| p[:z] }
      { values: bp[:values], fitness: bp[:fitness] }
    end

    {
      dimension: data['dimension'] || 0,
      variables: names,
      total_points: cache.size,
      total_evaluations: data['total_evaluations'] || 0,
      iterations: history.size,
      fitness_range: {
        min: min_fitness,
        max: max_fitness,
        avg: avg_fitness
      },
      best_point: best_point,
      comsol_file: data['comsol_file'],
      method: data['methodcall'],
      timestamp: data['timestamp'],
      points: points,
      plot_3d_data: {
        points: points,
        variable_names: names,
        selected_x_name: names[selected_x_index],
        selected_y_name: names[selected_y_index],
        dimension: data['dimension'] || 0
      },
      fitness_history_data: {
        history: history,
        iterations: (1..history.length).to_a
      }
    }
  end

  def prepare_3d_plot_data(json_result, selected_x_index = 0, selected_y_index = 1)
    extract_stats(json_result, selected_x_index, selected_y_index)[:plot_3d_data]
  end

  def prepare_fitness_history_data(json_result)
    extract_stats(json_result)[:fitness_history_data]
  end

  def calculate_median(points)
    return 0 if points.blank?

    fitness_values = points.map { |p| p[:z] }.compact.sort
    size = fitness_values.size

    if size.zero?
      0
    elsif size.odd?
      fitness_values[size / 2]
    else
      (fitness_values[size / 2 - 1] + fitness_values[size / 2]) / 2.0
    end
  end


  def info_row(label, value, truncate: false)
    value_class = truncate ? 'truncate' : ''
    content_tag(:div, class: 'flex justify-between items-start') do
      content_tag(:span, label, class: 'text-sm text-gray-600 font-medium') +
        content_tag(:span, value, class: "text-sm text-gray-900 text-right #{value_class}")
    end
  end

  def format_timestamp(timestamp)
    return timestamp unless timestamp
    Time.parse(timestamp).strftime('%d.%m.%Y, %H:%M:%S')
  rescue
    timestamp
  end

  def format_best_point(best_point, variables)
    return 'N/A' unless best_point && best_point[:values]

    variables.each_with_index.map do |var, i|
      "#{var}: #{sprintf('%.4f', best_point[:values][i])}"
    end.join(', ')
  end
end