import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    plot3d: Object,
    fitnessHistory: Object
  }

  connect() {
    // Ленивая загрузка графиков после рендера DOM
    this.renderPlots()
  }

  renderPlots() {
    // Используем requestIdleCallback для загрузки графиков в свободное время браузера
    if ('requestIdleCallback' in window) {
      requestIdleCallback(() => this.draw3dPlot(), { timeout: 1000 })
      requestIdleCallback(() => this.drawFitnessHistoryPlot(), { timeout: 2000 })
    } else {
      // Fallback для браузеров без поддержки requestIdleCallback
      setTimeout(() => this.draw3dPlot(), 100)
      setTimeout(() => this.drawFitnessHistoryPlot(), 200)
    }
  }

  draw3dPlot() {
    const data = this.plot3dValue
    if (!data?.points?.length) return

    const plotElement = document.getElementById('optimization-plot')
    if (!plotElement) return

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

    Plotly.newPlot(plotElement, [trace], layout, { responsive: true })
  }

  drawFitnessHistoryPlot() {
    const data = this.fitnessHistoryValue
    if (!data?.history?.length) return

    const plotElement = document.getElementById('fitness-history-plot')
    if (!plotElement) return

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

    Plotly.newPlot(plotElement, [trace], layout, { responsive: true })
  }

  resetCamera() {
    Plotly.relayout('optimization-plot', { 'scene.camera.eye': { x: 1.5, y: 1.5, z: 1.5 } })
  }

  downloadPlot() {
    const plotElement = document.getElementById('optimization-plot')
    if (plotElement) {
      Plotly.downloadImage(plotElement, { format: 'png', filename: 'optimization_plot' })
    }
  }
}
