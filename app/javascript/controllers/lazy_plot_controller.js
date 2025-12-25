import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    plot3d: Object,
    fitnessHistory: Object,
    experimentId: Number,
    projectId: Number
  }

  connect() {
    this.renderPlots()
  }

  renderPlots() {
    if ('requestIdleCallback' in window) {
      requestIdleCallback(() => this.draw3dPlot(), { timeout: 1000 })
      requestIdleCallback(() => this.drawFitnessHistoryPlot(), { timeout: 2000 })
    } else {
      setTimeout(() => this.draw3dPlot(), 100)
      setTimeout(() => this.drawFitnessHistoryPlot(), 200)
    }
  }

  draw3dPlot() {
    const data = this.plot3dValue
    if (!data?.points?.length) {
      const plotElement = document.getElementById('optimization-plot')
      if (plotElement) {
        plotElement.innerHTML = '<div class="flex items-center justify-center h-full text-gray-400">Нет данных для отображения</div>'
      }
      return
    }

    const plotElement = document.getElementById('optimization-plot')
    if (!plotElement) return

    if (plotElement.data && Plotly) {
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
          `${data.selected_x_name}: ${p.x.toFixed(4)}<br>` +
          `${data.selected_y_name}: ${p.y.toFixed(4)}<br>` +
          `Fitness: ${p.z.toFixed(4)}`
      ),
      hovertemplate: '%{text}<extra></extra>'
    }

    const layout = {
      scene: {
        xaxis: { title: { text: data.selected_x_name }, gridcolor: '#e5e7eb', showbackground: true, backgroundcolor: '#f9fafb' },
        yaxis: { title: { text: data.selected_y_name }, gridcolor: '#e5e7eb', showbackground: true, backgroundcolor: '#f9fafb' },
        zaxis: { title: { text: 'fitness' }, gridcolor: '#e5e7eb', showbackground: true, backgroundcolor: '#f9fafb' },
        camera: { eye: { x: 1.5, y: 1.5, z: 1.5 } }
      },
      margin: { l: 0, r: 0, b: 0, t: 50 }
    }

    Plotly.newPlot(plotElement, [trace], layout, {
      responsive: true,
      displaylogo: false
    })
  }

  drawFitnessHistoryPlot() {
    const data = this.fitnessHistoryValue
    if (!data?.history?.length) {
      const plotElement = document.getElementById('fitness-history-plot')
      if (plotElement) {
        plotElement.innerHTML = '<div class="flex items-center justify-center h-full text-gray-400">Нет данных истории</div>'
      }
      return
    }

    const plotElement = document.getElementById('fitness-history-plot')
    if (!plotElement) return

    if (plotElement.data && Plotly) {
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
          `Итерация: ${data.iterations[i]}<br>Лучшее значение: ${fitness.toFixed(4)}`
      ),
      hovertemplate: '%{text}<extra></extra>'
    }

    const layout = {
      title: { text: 'История fitness', font: { size: 16 } },
      xaxis: { title: 'Номер итерации', gridcolor: '#e5e7eb' },
      yaxis: { title: 'Лучшее значение fitness', gridcolor: '#e5e7eb' },
      margin: { l: 70, r: 20, b: 70, t: 50 },
      plot_bgcolor: 'white',
      paper_bgcolor: 'white'
    }

    Plotly.newPlot(plotElement, [trace], layout, {
      responsive: true,
      displaylogo: false
    })
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

  async updateParams() {
    const paramXSelect = document.getElementById('param-x-select')
    const paramYSelect = document.getElementById('param-y-select')

    if (!paramXSelect || !paramYSelect) return

    const paramX = paramXSelect.value
    const paramY = paramYSelect.value

    this.showLoading()
    this.showLoading()

    try {
      const response = await fetch(`/projects/${this.projectIdValue}/experiments/${this.experimentIdValue}/update_plot_data?param_x=${paramX}&param_y=${paramY}`, {
        headers: {
          'Accept': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        }
      })

      if (!response.ok) throw new Error('Failed to fetch data')

      const data = await response.json()

      this.plot3dValue = data.plot_3d
      this.fitnessHistoryValue = data.fitness_history

      this.draw3dPlot()
      this.drawFitnessHistoryPlot()

    } catch (error) {
      console.error('Error updating plots:', error)
      this.hideLoading()
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