import { Controller } from "@hotwired/stimulus"
import { post } from "@rails/request.js"
import { nextFrame } from "helpers/timing_helpers";

// 与 MySQL ngram 一致：至少 2 个字符才进入搜索页
const SEARCH_MIN_LENGTH = 2

export default class extends Controller {
  static targets = [ "turboFrame", "search", "searchInput", "form", "buttonsContainer" ]
  static outlets = [ "dialog" ]
  static values = {
    searchUrl: String,
  }

  #searchQueryTooShort() {
    const query = this.searchInputTarget.value?.trim() ?? ""
    return query.length > 0 && query.length < SEARCH_MIN_LENGTH
  }

  dialogOutletConnected(outlet, element) {
    outlet.close()
    this.#clearTurboFrame()
  }

  reset() {
    this.dialogOutlet.close()
    this.#clearTurboFrame()

    this.#showItem(this.buttonsContainerTarget)
    this.#hideItem(this.searchTarget)
  }

  clearInput() {
    if (this.searchInputTarget.value) {
      this.searchInputTarget.value = ""
      this.searchInputTarget.focus()
    } else {
      this.reset()
    }
  }

  showModalAndSubmit(event) {
    if (this.#searchQueryTooShort()) return
    this.showModal()
    this.formTarget.requestSubmit()
    this.#restoreFocusAfterTurboFrameLoads()
  }

  showModal() {
    this.dialogOutlet.open()
  }

  search(event) {
    this.#showItem(this.searchTarget)
    this.#hideItem(this.buttonsContainerTarget)

    const query = this.searchInputTarget.value.trim()
    if (query.length >= SEARCH_MIN_LENGTH) {
      this.showModalAndSubmit()
    } else {
      this.#loadTurboFrame()
    }
  }

  #restoreFocusAfterTurboFrameLoads() {
    this.turboFrameTarget.addEventListener("turbo:frame-load", () => {
      this.searchInputTarget.focus()
    }, { once: true })
  }

  #loadTurboFrame() {
    this.turboFrameTarget.src = this.searchUrlValue
  }

  #clearTurboFrame() {
    this.turboFrameTarget.removeAttribute("src")
    this.turboFrameTarget.innerHtml = ""
  }

  async #showItem(element) {
    element.removeAttribute("hidden")

    const autofocusElement = element.querySelector("[autofocus]")

    autofocusElement?.focus()
    await nextFrame()
    autofocusElement?.select()
  }

  #hideItem(element) {
    element.setAttribute("hidden", "hidden")
  }
}
