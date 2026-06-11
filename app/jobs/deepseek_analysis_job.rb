class DeepseekAnalysisJob < ApplicationJob
  queue_as :default

  def perform(experiment_id, query, user_id, connection_id = nil)
    experiment = Experiment.find_by(id: experiment_id)

    if experiment.nil?
      broadcast_error(connection_id, "Experiment not found")
      return
    end

    json_result = experiment.json_results.order(created_at: :desc).first

    if json_result.nil? || json_result.metadata.blank?
      broadcast_error(connection_id, "No data found")
      return
    end

    data = json_result.metadata

    api_key = Rails.application.credentials.deepseek_api_key

    if api_key.blank?
      broadcast_error(connection_id, "API key not configured")
      return
    end

    client = OpenAI::Client.new(
      access_token: api_key,
      uri_base: "https://api.deepseek.com",
      request_timeout: 120
    )

    prompt = build_prompt(query, data)

    response = client.chat(
      parameters: {
        model: "deepseek-reasoner",
        messages: [
          {
            role: "system",
            content: "Ты эксперт по визуализации данных с Plotly. Всегда возвращай только JSON объект для Plotly. Никогда не добавляй текст или пояснения. Используй данные, которые тебе даны. Никогда не используй null в массивах."
          },
          {
            role: "user",
            content: prompt
          }
        ],
        max_tokens: 64000,
        response_format: { type: "json_object" }
      }
    )

    result = JSON.parse(response.dig("choices", 0, "message", "content"))

    broadcast_result(connection_id, result)

  rescue => e
    Rails.logger.error "DeepSeek error: #{e.message}"
    broadcast_error(connection_id, e.message)
  end

  private

  def build_prompt(query, data)
    <<~PROMPT
      Ты эксперт по визуализации данных с Plotly.

      Доступные типы графиков (type):
      - "scatter" - точечный график, линии, точки
      - "scatter3d" - 3D точечный график
      - "bar" - столбчатая диаграмма
      - "heatmap" - тепловая карта
      - "contour" - контурный график
      - "histogram" - гистограмма
      - "box" - ящик с усами
      - "violin" - скрипичный график

      Доступные режимы (mode) для type="scatter" и "scatter3d":
      - "markers" - только точки
      - "lines" - только линии
      - "lines+markers" - линии и точки
      - "text" - только текст
      - "markers+text" - точки и текст
      - "lines+text" - линии и текст
      - "lines+markers+text" - линии, точки и текст

      Настройки маркеров (marker):
      - "size": число - размер точек
      - "color": строка или массив - цвет точек ('red', 'blue', '#FF0000')
      - "colorscale": строка - цветовая шкала ('Viridis', 'Plasma', 'Cividis', 'Inferno', 'Magma')
      - "opacity": число от 0 до 1 - прозрачность
      - "symbol": строка - форма точки ('circle', 'square', 'diamond', 'cross', 'x', 'star')
      - "showscale": true/false - показывать цветовую шкалу
      - "colorbar": {"title": "Заголовок"} - настройки цветовой шкалы

      Настройки линий (line):
      - "color": строка - цвет линии
      - "width": число - толщина линии
      - "dash": строка - стиль линии ('solid', 'dot', 'dash', 'longdash', 'dashdot')

      Настройки layout:
      - "title": строка - заголовок графика
      - "xaxis": {"title": "Подпись оси X", "range": [мин, макс]}
      - "yaxis": {"title": "Подпись оси Y", "range": [мин, макс]}
      - "scene": { - для 3D графиков
          "xaxis": {"title": "Подпись X"},
          "yaxis": {"title": "Подпись Y"},
          "zaxis": {"title": "Подпись Z"}
        }
      - "width": число - ширина графика в пикселях
      - "height": число - высота графика в пикселях
      - "hovermode": "closest" - поведение при наведении
      - "showlegend": true/false - показывать легенду
      - "legend": {"x": 0, "y": 1, "xanchor": "left"} - позиция легенды
      - "template": "plotly_white" - тема оформления

      ПРИМЕР 1: 2D точечный график с цветом по fitness
      {
        "traces": [
          {
            "x": [0.0259, 0.0279, 0.0301],
            "y": [0.0189, 0.0235, 0.0229],
            "mode": "markers",
            "type": "scatter",
            "name": "Точки поиска",
            "marker": {
              "size": 10,
              "color": [10416, 10451, 10469],
              "colorscale": "Viridis",
              "showscale": true,
              "colorbar": {"title": "Fitness"}
            }
          }
        ],
        "layout": {
          "title": "Визуализация оптимизации",
          "xaxis": {"title": "Параметр cx"},
          "yaxis": {"title": "Параметр cy"},
          "hovermode": "closest",
          "template": "plotly_white"
        }
      }

      ПРИМЕР 2: 3D график
      {
        "traces": [
          {
            "x": [0.0259, 0.0279, 0.0301],
            "y": [0.0189, 0.0235, 0.0229],
            "z": [10416, 10451, 10469],
            "mode": "markers",
            "type": "scatter3d",
            "name": "Пространство поиска",
            "marker": {
              "size": 6,
              "color": [10416, 10451, 10469],
              "colorscale": "Viridis",
              "showscale": true
            }
          }
        ],
        "layout": {
          "title": "3D визуализация",
          "scene": {
            "xaxis": {"title": "cx"},
            "yaxis": {"title": "cy"},
            "zaxis": {"title": "Fitness"}
          }
        }
      }

      ПРИМЕР 3: График сходимости
      {
        "traces": [
          {
            "x": [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
            "y": [10400, 10397, 10395, 10392, 10390, 10388, 10385, 10383, 10380, 10378],
            "mode": "lines+markers",
            "type": "scatter",
            "name": "Лучший fitness",
            "line": {"color": "red", "width": 2},
            "marker": {"size": 8, "color": "red", "symbol": "circle"}
          }
        ],
        "layout": {
          "title": "Сходимость алгоритма",
          "xaxis": {"title": "Итерация", "range": [0, 11]},
          "yaxis": {"title": "Fitness значение"},
          "showlegend": true
        }
      }

      ПРИМЕР 4: Гистограмма распределения fitness
      {
        "traces": [
          {
            "x": [10400, 10450, 10500, 10550, 10600, 10650, 10700],
            "type": "histogram",
            "name": "Распределение fitness",
            "marker": {"color": "blue", "opacity": 0.7},
            "nbinsx": 20
          }
        ],
        "layout": {
          "title": "Гистограмма значений fitness",
          "xaxis": {"title": "Fitness"},
          "yaxis": {"title": "Частота"}
        }
      }

      ПРИМЕР 5: Ящик с усами
      {
        "traces": [
          {
            "y": [10400, 10450, 10500, 10550, 10600],
            "type": "box",
            "name": "Fitness",
            "boxmean": "sd",
            "marker": {"color": "lightblue"}
          }
        ],
        "layout": {
          "title": "Статистика fitness",
          "yaxis": {"title": "Fitness"}
        }
      }

      Запрос пользователя: #{query}

      Данные эксперимента:
      #{JSON.generate(data)}

      Проанализируй запрос и данные. Выбери подходящий тип графика.
      Верни ТОЛЬКО JSON для Plotly, без пояснений. Не добавляй null значения. 
      Если данные содержат пропуски в нужных для графика полях, не используй эти конкретные объекты для графика, ПРОПУСКАЙ их. 
      Не обрезай JSON и возвращай его в корректном формате. Если результат превышает ограничение по токенам, не обрезай ответ, удали некоторое кол-во точек так, чтобы ответ не превышал ограничение по токенам, при этом сохрани структуру JSON.
    PROMPT
  end

  def broadcast_result(connection_id, result)
    if connection_id
      # WebSocket broadcast
      ActionCable.server.broadcast("deepseek_channel_#{connection_id}", {
        type: "result",
        plotly_data: result
      })
    end
  end

  def broadcast_error(connection_id, error_message)
    if connection_id
      ActionCable.server.broadcast("deepseek_channel_#{connection_id}", {
        type: "error",
        error: error_message
      })
    end
  end
end
