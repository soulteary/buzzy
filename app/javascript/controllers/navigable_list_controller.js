import { Controller } from "@hotwired/stimulus"
import { nextFrame } from "helpers/timing_helpers"

export default class extends Controller {
  static targets = [ "item" ]
  static values = { selectionAttribute: { type: String, default: "aria-current" } }

  // Actions

  navigate(event) {
    if (this.itemTargets.includes(event.target)) {
      this.#keyHandlers[event.key]?.call(this, event)
    }
  }

  select({ target }) {
    this.#setCurrentFrom(target)
  }

  selectCurrentOrLast(event) {
    if (this.currentItem) {
      this.#setCurrentFrom(this.currentItem)
    } else {
      this.selectLast()
    }
  }

  selectLast() {
    this.#setCurrentFrom(this.itemTargets[this.itemTargets.length - 1])
  }

  #selectPrevious() {
    if (this.currentItem.previousElementSibling) {
      this.#setCurrentFrom(this.currentItem.previousElementSibling)
    }
  }

  #selectNext() {
    if (this.currentItem.nextElementSibling) {
      this.#setCurrentFrom(this.currentItem.nextElementSibling)
    }
  }

  async #setCurrentFrom(element) {
    const selectedItem = this.itemTargets.find(item => item.contains(element))

    if (selectedItem) {
      this.#clearSelection()
      selectedItem.setAttribute(this.selectionAttributeValue, "true")
      this.currentItem = selectedItem
      await nextFrame()
      this.currentItem.focus()
    }
  }

  #clearSelection() {
    for (const item of this.itemTargets) {
      item.removeAttribute(this.selectionAttributeValue)
    }
  }

  #handleArrowKey(event, fn) {
    if (event.shiftKey || event.metaKey || event.ctrlKey) { return }
    fn.call()
    event.preventDefault()
  }

  #keyHandlers = {
    ArrowDown(event) {
      this.#handleArrowKey(event, this.#selectNext.bind(this))
    },
    ArrowUp(event) {
      this.#handleArrowKey(event, this.#selectPrevious.bind(this))
    },
    ArrowRight(event) {
      this.#handleArrowKey(event, this.#selectNext.bind(this))
    },
    ArrowLeft(event) {
      this.#handleArrowKey(event, this.#selectPrevious.bind(this))
    }
  }
}
