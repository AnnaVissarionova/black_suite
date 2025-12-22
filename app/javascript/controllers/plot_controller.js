// app/javascript/controllers/plot_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["container"]
    static values = {
        plotData: Object,
        experimentId: Number,
        paramX: Number,
        paramY: Number
    }

    connect() {
        if (this.hasPlotDataValue) {
            this.draw3dPlot()
        }
    }

    draw3dPlot() {
        const data = this.plotDataValue

        if (!data?.points?.length) return

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
                `Фитнес: ${p.z.toFixed(4)}`
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

        // Используем глобальный Plotly из CDN
        if (typeof Plotly !== 'undefined') {
            Plotly.newPlot(this.containerTarget, [trace], layout)
        }
    }

    resetCamera() {
        if (typeof Plotly !== 'undefined') {
            Plotly.relayout(this.containerTarget, { 'scene.camera.eye': { x: 1.5, y: 1.5, z: 1.5 } })
        }
    }

    download() {
        if (typeof Plotly !== 'undefined') {
            Plotly.downloadImage(this.containerTarget, { format: 'png', filename: 'optimization_plot' })
        }
    }

    async updatePlot() {
        const formData = new FormData()
        formData.append('param_x', this.paramXValue)
        formData.append('param_y', this.paramYValue)

        try {
            const response = await fetch(`/projects/${this.data.get('projectId')}/experiments/${this.experimentIdValue}/update_plot_params`, {
                method: 'PATCH',
                headers: {
                    'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content,
                    'Accept': 'text/vnd.turbo-stream.html'
                },
                body: formData
            })

            if (response.ok) {
                const html = await response.text()
                document.querySelector(`#plot_3d_${this.experimentIdValue}`).innerHTML = html
            }
        } catch (error) {
            console.error('Error updating plot:', error)
        }
    }
}