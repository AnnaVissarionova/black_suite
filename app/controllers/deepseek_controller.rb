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

    data = json_result.metadata

    api_key = Rails.application.credentials.deepseek_api_key

    if api_key.blank?
      render json: { error: "API key not configured" }, status: 500
      return
    end

    client = OpenAI::Client.new(
      access_token: api_key,
      uri_base: "https://api.deepseek.com",
      request_timeout: 60
    )

    prompt = <<~PROMPT
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

      Запрос пользователя: #{params[:query]}

      Данные эксперимента:
      #{JSON.generate(data)}

      Проанализируй запрос и данные. Выбери подходящий тип графика.
      Верни ТОЛЬКО JSON для Plotly, без пояснений. Не добавляй null значения. 
      Если данные содержат пропуски в нужных для графика полях, не используй эти конкретные объекты для графика, ПРОПУСКАЙ их. 
      Не обрезай JSON и возвращай его в корректном формате.
    PROMPT

    response = client.chat(
      parameters: {
        model: "deepseek-chat",
        messages: [
          {
            role: "system",
            content: "Ты эксперт по визуализации данных с Plotly. Всегда возвращай только JSON объект для Plotly. Никогда не добавляй текст или пояснения. Используй данные, которые тебе даны.Никогда не используй null в массивах."
          },
          {
            role: "user",
            content: prompt
          }
        ],
        temperature: 0.5,
        max_tokens: 8000,
        response_format: { type: "json_object" }
      }
    )

    Rails.logger.info(response.dig("choices", 0, "message", "content"))

    result = JSON.parse(response.dig("choices", 0, "message", "content"))
    Rails.logger.info(result)

    render json: { plotly_data: result }

  rescue => e
    Rails.logger.error "DeepSeek error: #{e.message}"
    render json: { error: e.message }, status: 500
  end
end
