import { Controller } from "@hotwired/stimulus"
import { debounce, nextFrame } from "helpers/timing_helpers"

export default class extends Controller {
  static targets = ["input"]
  static values = { key: String }

  initialize() {
    this.save = debounce(this.save.bind(this), 300)
  }

  connect() {
    this.restoreContent()
  }

  submit({ detail: { success } }) {
    if (success) {
      this.#clear()
    }
  }

  save() {
    const content = this.inputTarget.value
    if (content) {
      localStorage.setItem(this.keyValue, content)
    } else {
      this.#clear()
    }
  }

  async restoreContent() {
    await nextFrame()
    const savedContent = localStorage.getItem(this.keyValue)
    if (!savedContent) return

    const input = this.inputTarget
    input.value = input.tagName === "TEXTAREA" ? savedContent : `<div>${savedContent}</div>`
    this.#triggerChangeEvent(input, savedContent)
  }

  // Private

  #clear() {
    localStorage.removeItem(this.keyValue)
  }

  #triggerChangeEvent(element, newValue) {
    element.dispatchEvent(new CustomEvent("editor:change", {
      bubbles: true,
      detail: { previousContent: "", newContent: newValue }
    }))
  }
}
