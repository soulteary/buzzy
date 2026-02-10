import { Controller } from "@hotwired/stimulus"

const TOKEN_FORMAT = (display, handle) => `[@${display}](${handle})`

export default class extends Controller {
  static targets = ["textarea", "menu"]
  static values = { url: String }
  #triggerAt = 0
  #replaceTo = 0
  #cachedItems = null
  #activeIndex = -1
  #searchVersion = 0

  connect() {
    if (!this.hasUrlValue) return
    this.textareaTarget.setAttribute("aria-haspopup", "listbox")
    this.textareaTarget.setAttribute("aria-expanded", "false")
    this.#bindEditor()
    this.element.addEventListener("markdown-editor:ready", this.#boundOnEditorReady)
    document.addEventListener("click", this.#boundOnDocumentClick)
  }

  disconnect() {
    this.element.removeEventListener("markdown-editor:ready", this.#boundOnEditorReady)
    document.removeEventListener("click", this.#boundOnDocumentClick)
    this.#unbindCm()
  }

  get #boundOnEditorReady() {
    if (!this._boundOnEditorReady) this._boundOnEditorReady = () => this.#bindEditor()
    return this._boundOnEditorReady
  }

  #bindEditor() {
    const easymde = this.element.easymde
    if (easymde) {
      this.#unbindCm()
      this._cm = easymde.codemirror
      this._cm.on("change", this.#onInputBound)
      this._cm.on("keydown", this.#onKeydownBound)
    } else {
      this.textareaTarget.addEventListener("input", this.#onInputBound)
      this.textareaTarget.addEventListener("keydown", this.#onKeydownBound)
    }
  }

  #unbindCm() {
    if (this._cm) {
      this._cm.off("change", this.#onInputBound)
      this._cm.off("keydown", this.#onKeydownBound)
      this._cm = null
    }
    this.textareaTarget.removeEventListener("input", this.#onInputBound)
    this.textareaTarget.removeEventListener("keydown", this.#onKeydownBound)
  }

  get #onInputBound() {
    if (!this._onInputBound) this._onInputBound = this.#onInput.bind(this)
    return this._onInputBound
  }

  get #onKeydownBound() {
    if (!this._onKeydownBound) this._onKeydownBound = this.#onKeydown.bind(this)
    return this._onKeydownBound
  }

  get #boundOnDocumentClick() {
    if (!this._boundOnDocumentClick) this._boundOnDocumentClick = this.#onDocumentClick.bind(this)
    return this._boundOnDocumentClick
  }

  #getValue() {
    if (this._cm) return this._cm.getValue()
    return this.textareaTarget.value
  }

  #getCursorOffset() {
    if (this._cm) return this._cm.indexFromPos(this._cm.getCursor())
    return this.textareaTarget.selectionStart
  }

  #onInput() {
    const value = this.#getValue()
    const cursorOffset = this.#getCursorOffset()
    const mentionContext = this.#findMentionContext(value, cursorOffset)
    if (!mentionContext) return this.#hide()
    this.#triggerAt = mentionContext.triggerAt
    this.#replaceTo = mentionContext.replaceTo
    const version = ++this.#searchVersion
    this.#fetchAndShow(mentionContext.query, version)
  }

  #onKeydown(cmOrEvent, maybeEvent) {
    const event = this.#extractKeyboardEvent(cmOrEvent, maybeEvent)
    if (!event) return
    if (!this.hasMenuTarget || !this.menuTarget.classList.contains("is-open")) return
    if (event.key === "Escape") return this.#hideAndPrevent(event)
    if (event.key === "ArrowDown") return this.#moveSelection(1, event)
    if (event.key === "ArrowUp") return this.#moveSelection(-1, event)
    if ((event.key === "Enter" || event.key === "Tab") && this.#activeIndex >= 0) {
      const activeItem = this.menuTarget.querySelector(`[data-index="${this.#activeIndex}"]`)
      if (activeItem) {
        this.#insert(activeItem.dataset.display, activeItem.dataset.userReference)
        event.preventDefault()
        event.stopPropagation()
      }
    }
  }

  #extractKeyboardEvent(cmOrEvent, maybeEvent) {
    // DOM listener: #onKeydown(event); CodeMirror listener: #onKeydown(cm, event)
    if (maybeEvent && typeof maybeEvent.key === "string") return maybeEvent
    if (cmOrEvent && typeof cmOrEvent.key === "string") return cmOrEvent
    return null
  }

  #onDocumentClick(event) {
    if (this.hasMenuTarget && this.menuTarget.classList.contains("is-open") && !this.element.contains(event.target)) {
      this.#hide()
    }
  }

  #hideAndPrevent(event) {
    this.#hide()
    event.preventDefault()
  }

  #moveSelection(step, event) {
    const items = this.menuTarget.querySelectorAll(".markdown-prompt__item")
    if (!items.length) return
    const next = this.#activeIndex < 0
      ? (step > 0 ? 0 : items.length - 1)
      : (this.#activeIndex + step + items.length) % items.length
    this.#setActiveIndex(next)
    event.preventDefault()
  }

  // Allow spaces in query so "John S" can match "John Smith"
  #findMentionContext(value, cursorOffset) {
    const beforeCursor = value.slice(0, cursorOffset)
    const match = beforeCursor.match(/(^|\s)@([\p{L}\p{N}\p{Zs}._-]*)$/u)
    if (!match) return null
    const query = match[2] || ""
    const triggerAt = cursorOffset - query.length - 1
    return { query, triggerAt, replaceTo: cursorOffset }
  }

  async #fetchAndShow(query, version) {
    try {
      if (!this.#cachedItems) {
        const response = await fetch(this.urlValue, { headers: { Accept: "text/html" } })
        if (!response.ok) return this.#hide()
        const html = await response.text()
        const doc = new DOMParser().parseFromString(html, "text/html")
        this.#cachedItems = Array.from(doc.querySelectorAll("lexxy-prompt-item")).map((el) => ({
          sgid: el.getAttribute("sgid") || "",
          display: (el.getAttribute("data-display") || el.textContent?.trim() || "@").trim(),
          handle: (el.getAttribute("data-user-handle") || "").trim(),
          userId: (el.getAttribute("data-user-id") || "").trim(),
          searchText: (el.getAttribute("search") || "").trim().toLowerCase()
        })).filter((item) => item.handle || item.userId)
      }
      if (version !== this.#searchVersion) return
      if (!this.#findMentionContext(this.#getValue(), this.#getCursorOffset())) return this.#hide()
      const q = query.toLowerCase()
      const filtered = q
        ? this.#cachedItems.filter((item) => {
            const haystack = item.searchText || item.display.toLowerCase()
            return haystack.includes(q)
          })
        : this.#cachedItems
      this.#showItems(filtered)
    } catch {
      this.#hide()
    }
  }

  #showItems(items) {
    if (!this.hasMenuTarget) return
    this.menuTarget.innerHTML = ""
    this.menuTarget.hidden = false
    this.menuTarget.classList.add("is-open")
    this.#activeIndex = -1

    const menuId = this.menuTarget.id || (this.menuTarget.id = `markdown-prompt-menu-${Math.random().toString(36).slice(2, 10)}`)
    this.menuTarget.setAttribute("role", "listbox")
    this.#setComboboxAria(true, menuId)

    items.slice(0, 10).forEach((item) => {
      const button = document.createElement("button")
      button.type = "button"
      button.className = "markdown-prompt__item"
      button.id = `${menuId}-opt-${this.menuTarget.children.length}`
      button.setAttribute("role", "option")
      const title = document.createElement("span")
      title.className = "markdown-prompt__item-primary"
      title.textContent = item.display
      button.appendChild(title)
      button.dataset.userReference = item.handle || item.userId
      button.dataset.display = item.display
      button.dataset.index = String(this.menuTarget.children.length)
      button.addEventListener("mouseenter", () => this.#setActiveIndex(Number(button.dataset.index)))
      button.addEventListener("mousedown", (e) => e.preventDefault())
      button.addEventListener("click", (e) => {
        e.preventDefault()
        this.#insert(button.dataset.display, button.dataset.userReference)
      })
      this.menuTarget.appendChild(button)
    })
    if (items.length === 0) this.#hide()
    if (items.length > 0) {
      this.#setActiveIndex(0)
      this.#positionMenu()
    }
  }

  #setComboboxAria(expanded, menuId) {
    const input = this.textareaTarget
    input.setAttribute("aria-haspopup", "listbox")
    input.setAttribute("aria-expanded", expanded ? "true" : "false")
    input.setAttribute("aria-controls", menuId || "")
    if (!expanded) input.removeAttribute("aria-activedescendant")
  }

  #positionMenu() {
    const menu = this.menuTarget
    const containerRect = this.element.getBoundingClientRect()

    let topPx = 0
    let leftPx = 0

    if (this._cm) {
      const coords = this._cm.cursorCoords(this._cm.getCursor(), "local")
      const editorRect = this._cm.getWrapperElement().getBoundingClientRect()
      leftPx = editorRect.left + coords.left - containerRect.left
      topPx = editorRect.top + coords.bottom - containerRect.top
    } else {
      const ta = this.textareaTarget
      const start = ta.selectionStart
      const before = ta.value.slice(0, start)
      const after = ta.value.slice(start)
      const div = document.createElement("div")
      const style = getComputedStyle(ta)
      ;[ "font", "fontSize", "lineHeight", "padding", "border", "boxSizing" ].forEach((p) => { div.style[p] = style[p] })
      div.style.position = "absolute"
      div.style.whiteSpace = "pre-wrap"
      div.style.wordWrap = "break-word"
      div.style.visibility = "hidden"
      div.appendChild(document.createTextNode(before))
      const span = document.createElement("span")
      span.textContent = "\u200b"
      div.appendChild(span)
      div.appendChild(document.createTextNode(after))
      document.body.appendChild(div)
      const rect = span.getBoundingClientRect()
      leftPx = rect.left - containerRect.left
      topPx = rect.bottom - containerRect.top
      document.body.removeChild(div)
    }

    menu.style.top = `${topPx + 4}px`
    menu.style.left = `${leftPx}px`
  }

  #setActiveIndex(index) {
    const items = this.menuTarget.querySelectorAll(".markdown-prompt__item")
    items.forEach((item) => {
      item.classList.remove("is-active")
      item.setAttribute("aria-selected", "false")
    })
    const active = items[index]
    if (!active) {
      this.#activeIndex = -1
      this.textareaTarget.removeAttribute("aria-activedescendant")
      return
    }
    active.classList.add("is-active")
    active.setAttribute("aria-selected", "true")
    this.textareaTarget.setAttribute("aria-activedescendant", active.id)
    active.scrollIntoView({ block: "nearest" })
    this.#activeIndex = index
  }

  #insert(display, reference) {
    const token = TOKEN_FORMAT(display, reference) + this.#insertedTokenSuffix()
    if (this._cm) {
      const from = this._cm.posFromIndex(this.#triggerAt)
      const to = this._cm.posFromIndex(this.#replaceTo)
      this._cm.replaceRange(token, from, to)
      this._cm.focus()
    } else {
      const ta = this.textareaTarget
      const before = ta.value.slice(0, this.#triggerAt)
      const after = ta.value.slice(this.#replaceTo)
      ta.value = before + token + after
      ta.selectionStart = ta.selectionEnd = before.length + token.length
      ta.dispatchEvent(new Event("input", { bubbles: true }))
    }
    this.#hide()
  }

  #insertedTokenSuffix() {
    const value = this.#getValue()
    const nextChar = value.slice(this.#replaceTo, this.#replaceTo + 1)
    if (nextChar === "") return " "
    if (/\s|[,.!?;:)\]]/.test(nextChar)) return ""
    return " "
  }

  #hide() {
    if (this.hasMenuTarget) {
      const menuId = this.menuTarget.id
      this.menuTarget.classList.remove("is-open")
      this.menuTarget.innerHTML = ""
      this.menuTarget.hidden = true
      this.#activeIndex = -1
      this.#setComboboxAria(false, menuId || "")
    }
  }
}
