import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    document.addEventListener("turbo:before-stream-render", (event) => {
      // console.log("Stream action:", event.target.action)
      // console.log("Stream target:", event.target.target)
      // console.log("Stream content:", event.target.templateContent.textContent)
    })
  }

  disconnect() {
    document.removeEventListener("turbo:before-stream-render", this.handleStream)
  }
}
