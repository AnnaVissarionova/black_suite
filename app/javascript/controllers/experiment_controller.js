import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["normalContent", "aiContent", "aiResponse", "aiQuery", "content"]
    loadingTimer = null;

    connect() {
    }

    loadExperiment(event) {
        const item = event.currentTarget
        const experimentId = item.dataset.experimentId
        const projectId = item.dataset.projectId

        if (!experimentId) return

        document.querySelectorAll('.experiment-list-item').forEach(el => {
            el.classList.remove('bg-secondary-100')
        })
        item.classList.add('bg-secondary-100')

        let url
        const isSharedProject = window.location.pathname.includes('/shared/project/')
        const shareToken = this.getShareToken()

        if (isSharedProject && shareToken) {
            url = `${window.location.origin}/shared/project/${shareToken}/experiment/${experimentId}?partial=true`
        } else if (projectId) {
            url = `${window.location.origin}/projects/${projectId}/experiment/${experimentId}?partial=true`
        } else {
            console.error("No valid mode detected")
            return
        }

        if (this.loadingTimer) clearTimeout(this.loadingTimer)
        this.loadingTimer = setTimeout(() => {
            this.showExperimentLoading()
        }, 1000)



        fetch(url, {
            headers: {
                'Accept': 'text/html',
                'X-Requested-With': 'XMLHttpRequest',
                'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content || ''
            }
        })
            .then(response => {
                if (!response.ok) throw new Error('Network response was not ok')
                return response.text()
            })
            .then(html => {
                if (this.loadingTimer) {
                    clearTimeout(this.loadingTimer)
                    this.loadingTimer = null
                }
                // Обновляем содержимое (заменит спиннер, если он уже показан)
                this.contentTarget.innerHTML = html
                this.contentTarget.classList.remove('flex', 'items-center', 'justify-center')
                if (typeof window.initExperimentPlots === 'function') {
                    window.initExperimentPlots()
                }
                window.dispatchEvent(new CustomEvent('experiment:loaded', { detail: { element: this.contentTarget } }))
            })
            .catch(error => {
                if (this.loadingTimer) {
                    clearTimeout(this.loadingTimer)
                    this.loadingTimer = null
                }
                console.error('Error loading experiment:', error)
                this.contentTarget.innerHTML = `
                <div class="text-center py-12 text-red-500">
                    <p>Ошибка загрузки эксперимента</p>
                    <p class="text-sm mt-2">${error.message}</p>
                </div>
            `
            })
    }

    showExperimentLoading() {
        this.contentTarget.innerHTML = `
      <div class="flex items-center justify-center py-12">
        <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-500"></div>
        <span class="ml-3 text-gray-500">Загрузка...</span>
      </div>
    `
    }

    getShareToken() {
        const matches = window.location.pathname.match(/\/shared\/(?:project|experiment)\/([^\/?#]+)/)
        return matches ? matches[1] : null
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
            console.log('Response from server:', data)

            if (data.connection_id) {
                // Сохраняем connection_id для WebSocket
                this.setupWebSocket(data.connection_id)
            } else if (data.error) {
                this.displayError(data.error)
            }
        } catch (error) {
            console.error("Error:", error)
            this.displayError(`Ошибка: ${error.message}`)
        }
    }

    setupWebSocket(connectionId) {
        const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:'
        const wsUrl = `${protocol}//${window.location.host}/cable`

        console.log('Connecting WebSocket to:', wsUrl)

        this.ws = new WebSocket(wsUrl)

        this.ws.onopen = () => {
            console.log('WebSocket connected, subscribing to channel')

            const subscribeMessage = {
                command: 'subscribe',
                identifier: JSON.stringify({
                    channel: 'DeepseekChannel',
                    connection_id: connectionId
                })
            }
            this.ws.send(JSON.stringify(subscribeMessage))
            console.log('Sent subscribe message:', subscribeMessage)
        }

        this.ws.onmessage = (event) => {
            console.log('Raw WebSocket message received:', event.data)

            try {
                const data = JSON.parse(event.data)
                console.log('Parsed WebSocket message:', data)

                if (data.message && data.message.type === 'result' && data.message.plotly_data) {
                    console.log('Rendering result from message.plotly_data')
                    this.renderPlots(data.message.plotly_data)
                    this.ws.close()
                }
                else if (data.message && data.message.type === 'error') {
                    console.log('Received error:', data.error)
                    this.displayError(data.message.error)
                    this.ws.close()
                }
                else {
                    console.log('Unknown message format:', data)
                }
            } catch (e) {
                console.error('Failed to parse WebSocket message:', e)
            }
        }

        this.ws.onerror = (error) => {
            console.error('WebSocket error:', error)
            this.displayError('Ошибка соединения с сервером')
        }

        this.ws.onclose = () => {
            console.log('WebSocket disconnected')
        }
    }

    renderPlots(plotlyData) {
        const container = this.aiResponseTarget
        if (!container) {
            console.error('aiResponseTarget not found')
            return
        }

        console.log('renderPlots called with:', plotlyData)

        container.innerHTML = ''

        let traces = plotlyData.traces
        let layout = plotlyData.layout || {
            title: 'График оптимизации',
            xaxis: { title: 'Итерации' },
            yaxis: { title: 'Значения' },
            template: 'plotly_white'
        }

        if (!traces || traces.length === 0) {
            container.innerHTML = '<div class="text-red-500 text-center py-8">Нет данных для построения графиков</div>'
            return
        }

        const plotDiv = document.createElement('div')
        plotDiv.id = 'ai-plot-' + Date.now()
        plotDiv.className = 'w-full h-[500px]'
        container.appendChild(plotDiv)

        if (typeof Plotly !== 'undefined') {
            Plotly.newPlot(plotDiv, traces, layout)
            console.log('Plot rendered successfully')
        } else {
            console.error('Plotly not loaded')
            container.innerHTML = '<div class="text-red-500">Plotly не загружен</div>'
        }
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

    getCsrfToken() {
        return document.querySelector("[name='csrf-token']")?.content || ""
    }

    escapeHtml(text) {
        const div = document.createElement("div")
        div.textContent = text
        return div.innerHTML
    }
}
