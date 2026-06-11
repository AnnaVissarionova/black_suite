import consumer from "./consumer"

consumer.subscriptions.create("DeepseekChannel", {
    connected() {
        console.log("Connected to DeepseekChannel")
    },

    disconnected() {
        console.log("Disconnected from DeepseekChannel")
    },

    received(data) {
        console.log("Received data:", data)
        if (window.handleDeepseekResponse) {
            window.handleDeepseekResponse(data)
        }
    }
})
