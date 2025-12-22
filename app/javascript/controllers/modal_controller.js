// app/javascript/controllers/modal_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["modal"]

    open(event) {
        event.preventDefault()
        const url = event.currentTarget.href

        fetch(url, {
            headers: { 'Accept': 'text/vnd.turbo-stream.html' }
        })
            .then(response => response.text())
            .then(html => {
                document.body.insertAdjacentHTML('beforeend', html)
            })
    }

    close() {
        this.modalTarget.remove()
    }

    closeWithKeyboard(event) {
        if (event.code === "Escape") {
            this.close()
        }
    }

    // Закрытие по клику вне модального окна
    closeBackground(event) {
        if (event.target === this.modalTarget) {
            this.close()
        }
    }
}