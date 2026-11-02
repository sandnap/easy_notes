import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  static values = { url: String }

  #timer

  connect() {
    this.element.setAttribute("data-notes-search-ready", "true")
  }

  search() {
    clearTimeout(this.#timer)
    this.#timer = setTimeout(() => this.#run(), 200)
  }

  disconnect() {
    clearTimeout(this.#timer)
  }

  async #run() {
    const query = this.element.value.trim()
    const url = new URL(this.urlValue, window.location.origin)
    url.searchParams.set("q", query)

    const response = await fetch(url, {
      headers: { Accept: "text/vnd.turbo-stream.html" },
      credentials: "same-origin"
    })
    const html = await response.text()
    Turbo.renderStreamMessage(html)
  }
}
