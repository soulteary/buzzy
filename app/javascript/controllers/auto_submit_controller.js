import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.element.addEventListener("turbo:submit-end", () => this.element.remove(), { once: true } )
    this.element.requestSubmit()
  }
}
