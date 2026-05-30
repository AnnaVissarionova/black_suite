import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["normalContent", "aiContent", "aiResponse", "aiQuery"]

    connect() {
    }

    toggleAiMode() {
        if (this.hasNormalContentTarget && this.hasAiContentTarget) {
            this.normalContentTarget.classList.toggle("hidden")
            this.aiContentTarget.classList.toggle("hidden")
        }
    }

    async sendAiQuery() {
        const query = this.aiQueryTarget?.value.trim()
        if (!query) return

        const experimentId = this.element.dataset.experimentId

        if (!experimentId) {
            this.displayError("ID эксперимента не найден")
            return
        }

        this.showLoading()

        try {
            const response = await fetch("/api/deepseek/analyze_experiment", {
                method: "POST",
                headers: {
                    "Content-Type": "application/json",
                    "X-CSRF-Token": this.getCsrfToken()
                },
                body: JSON.stringify({
                    query: query,
                    experiment_id: experimentId
                })
            })

            const data = await response.json()
            this.hideLoading()

            if (data.plotly_data) {
                this.renderPlots(data.plotly_data)
            } else if (data.error) {
                this.displayError(data.error)
            } else {
                this.displayError("Не удалось получить данные для графиков")
            }

        } catch (error) {
            console.error("Error:", error)
            this.hideLoading()
            this.displayError(`Ошибка: ${error.message}`)
        }
    }

    renderPlots(plotlyData) {
        const container = this.aiResponseTarget
        if (!container) return

        // Очищаем контейнер
        container.innerHTML = ''

        // Создаем контейнер для графиков
        const plotsContainer = document.createElement('div')
        plotsContainer.className = 'space-y-6'

        // Рендерим каждый график
        if (plotlyData.traces && plotlyData.traces.length > 0) {
            const plotDiv = document.createElement('div')
            plotDiv.id = 'ai-plot-' + Date.now()
            plotDiv.className = 'w-full h-[500px]'
            plotsContainer.appendChild(plotDiv)

            // Рендерим через Plotly
            if (typeof Plotly !== 'undefined') {
                Plotly.newPlot(plotDiv, plotlyData.traces, plotlyData.layout || {
                    title: 'График оптимизации',
                    xaxis: { title: 'Итерации' },
                    yaxis: { title: 'Значения' }
                })
            } else {
                plotsContainer.innerHTML = '<div class="text-red-500">Plotly не загружен</div>'
            }
        } else {
            plotsContainer.innerHTML = '<div class="text-gray-500 text-center py-8">Нет данных для построения графиков</div>'
        }

        container.appendChild(plotsContainer)
    }

    displayError(message) {
        const container = this.aiResponseTarget
        if (!container) return

        container.innerHTML = `
      <div class="bg-red-50 border border-red-200 rounded-lg p-4 text-red-600">
        <p class="text-sm">${this.escapeHtml(message)}</p>
      </div>
    `
    }

    showLoading() {
        const container = this.aiResponseTarget
        if (!container) return

        container.innerHTML = `
      <div class="flex items-center justify-center space-x-2 py-8">
        <div class="animate-spin rounded-full h-6 w-6 border-b-2 border-purple-500"></div>
        <div class="text-gray-500">DeepSeek генерирует графики...</div>
      </div>
    `
    }

    hideLoading() {
        // Ничего не делаем, loading заменится графиками
    }

    getCsrfToken() {
        return document.querySelector("[name='csrf-token']")?.content || ""
    }

    escapeHtml(text) {
        const div = document.createElement("div")
        div.textContent = text
        return div.innerHTML
    }
}
