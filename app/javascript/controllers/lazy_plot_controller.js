import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["paramX", "paramY", "optimizationPlot"]
  static values = {
    plot3d: Object,
    fitnessHistory: Object,
    experimentId: Number,
    projectId: Number
  }

  connect() {
        this.originalPlotData = JSON.parse(JSON.stringify(this.plot3dValue))
        this.originalFitnessData = JSON.parse(JSON.stringify(this.fitnessHistoryValue))
        this.renderPlots()
    }

  renderPlots() {
      if (window.Plotly) {
          this.draw3dPlot()
          this.drawFitnessHistoryPlot()
      } else {
          const checkPlotly = setInterval(() => {
              if (window.Plotly) {
                  clearInterval(checkPlotly)
                  this.draw3dPlot()
                  this.drawFitnessHistoryPlot()
              }
          }, 100)
      }
  }

  draw3dPlot() {
      const data = this.plot3dValue
      const plotElement = this.optimizationPlotTarget

      if (!plotElement || !data?.points?.length) {
          if (plotElement) {
              plotElement.innerHTML = '<div class="flex items-center justify-center h-full text-gray-400">Нет данных для отображения</div>'
          }
          return
      }

      if (window.Plotly) {
          Plotly.purge(plotElement)
      }

      const trace = {
          x: data.points.map(p => p.x),
          y: data.points.map(p => p.y),
          z: data.points.map(p => p.z),
          mode: 'markers',
          type: 'scatter3d',
          marker: {
              size: 5,
              color: data.points.map(p => p.z),
              colorscale: 'Viridis',
              colorbar: { title: 'fitness' },
              opacity: 0.8
          },
          text: data.points.map(p =>
              `${data.selected_x_name}: ${p.x?.toFixed(4)}<br>` +
              `${data.selected_y_name}: ${p.y?.toFixed(4)}<br>` +
              `Fitness: ${p.z?.toFixed(4)}`
          ),
          hovertemplate: '%{text}<extra></extra>'
      }

      const layout = {
          scene: {
              xaxis: {
                  title: { text: data.selected_x_name },
                  gridcolor: '#e5e7eb',
                  showbackground: true,
                  backgroundcolor: '#f9fafb'
              },
              yaxis: {
                  title: { text: data.selected_y_name },
                  gridcolor: '#e5e7eb',
                  showbackground: true,
                  backgroundcolor: '#f9fafb'
              },
              zaxis: {
                  title: { text: 'fitness' },
                  gridcolor: '#e5e7eb',
                  showbackground: true,
                  backgroundcolor: '#f9fafb'
              },
              camera: { eye: { x: 1.5, y: 1.5, z: 1.5 } }
          },
          margin: { l: 0, r: 0, b: 0, t: 50 }
      }

      const config = {
          responsive: true,
          displaylogo: false
      }

      window.Plotly.newPlot(plotElement, [trace], layout, config)
  }

  drawFitnessHistoryPlot() {
      const data = this.fitnessHistoryValue
      const plotElement = document.getElementById('fitness-history-plot')

      if (!plotElement || !data?.history?.length) {
          if (plotElement) {
              plotElement.innerHTML = '<div class="flex items-center justify-center h-full text-gray-400">Нет данных истории</div>'
          }
          return
      }

      // Очищаем предыдущий график
      if (window.Plotly) {
          Plotly.purge(plotElement)
      }

      const trace = {
          x: data.iterations,
          y: data.history,
          mode: 'lines+markers',
          type: 'scatter',
          line: { color: 'rgb(16, 185, 129)', width: 2 },
          marker: { size: 4, color: 'rgb(16, 185, 129)' },
          text: data.history.map((fitness, i) =>
              `Итерация: ${data.iterations[i]}<br>Лучшее значение: ${fitness?.toFixed(4)}`
          ),
          hovertemplate: '%{text}<extra></extra>'
      }

      const layout = {
          title: { text: 'История сходимости', font: { size: 16 } },
          xaxis: { title: 'Номер итерации', gridcolor: '#e5e7eb' },
          yaxis: { title: 'Лучшее значение', gridcolor: '#e5e7eb' },
          margin: { l: 70, r: 20, b: 70, t: 50 },
          plot_bgcolor: 'white',
          paper_bgcolor: 'white'
      }

      const config = {
          responsive: true,
          displaylogo: false
      }

      window.Plotly.newPlot(plotElement, [trace], layout, config)
  }

  resetCamera() {
    const plotElement = document.getElementById('optimization-plot')
    if (plotElement && Plotly) {
      Plotly.relayout(plotElement, { 'scene.camera.eye': { x: 1.5, y: 1.5, z: 1.5 } })
    }
  }

  downloadPlot() {
    const plotElement = document.getElementById('optimization-plot')
    if (plotElement && Plotly) {
      Plotly.downloadImage(plotElement, { format: 'png', filename: 'optimization_plot' })
    }
  }

    updateParams() {
        const paramX = this.hasParamXTarget ? parseInt(this.paramXTarget.value) : 0
        const paramY = this.hasParamYTarget ? parseInt(this.paramYTarget.value) : 1

        // Перестраиваем данные для новых параметров БЕЗ ЗАПРОСА К БЕКЕНДУ
        const updatedPlotData = this.rebuildPlotData(paramX, paramY)

        // Обновляем значения
        this.plot3dValue = updatedPlotData
        this.fitnessHistoryValue = this.originalFitnessData // История fitness не меняется

        // Перерисовываем графики
        this.draw3dPlot()
        this.drawFitnessHistoryPlot()
    }


    rebuildPlotData(selectedXIndex, selectedYIndex) {
        if (!this.originalPlotData || !this.originalPlotData.points) {
            return this.originalPlotData
        }

        const originalPoints = this.originalPlotData.points
        const variableNames = this.originalPlotData.variable_names || []

        // Перестраиваем точки с новыми x и y координатами
        const newPoints = originalPoints.map(point => ({
            x: point.values[selectedXIndex],
            y: point.values[selectedYIndex],
            z: point.fitness,
            values: point.values,
            fitness: point.fitness
        }))

        return {
            points: newPoints,
            variable_names: variableNames,
            selected_x_name: variableNames[selectedXIndex] || `Param ${selectedXIndex}`,
            selected_y_name: variableNames[selectedYIndex] || `Param ${selectedYIndex}`,
            dimension: this.originalPlotData.dimension || variableNames.length
        }
    }

  showLoading() {
    const plotsContainer = this.element
    if (plotsContainer) {
      plotsContainer.innerHTML = `
        <div class="space-y-8">
          <div class="bg-white rounded-xl shadow p-6 mb-8">
            <div class="flex justify-between items-center mb-4">
              <h3 class="font-medium text-gray-900">3D визуализация</h3>
            </div>
            <div class="flex items-center justify-center h-96">
              <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-500"></div>
              <span class="ml-3 text-gray-500">Обновление 3D графика...</span>
            </div>
          </div>
          
          <div class="bg-white rounded-xl shadow p-6">
            <h3 class="font-medium text-gray-900 mb-4">История fitness</h3>
            <div class="flex items-center justify-center h-64">
              <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-500"></div>
              <span class="ml-3 text-gray-500">Обновление графика истории...</span>
            </div>
          </div>
        </div>
      `
    }
  }

  hideLoading() {
  }
}
