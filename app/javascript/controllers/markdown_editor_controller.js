import { Controller } from "@hotwired/stimulus"
import loadEasyMDE from "helpers/easymde_loader"
import { DirectUpload } from "@rails/activestorage"

export default class extends Controller {
  static targets = ["textarea", "hiddenInput", "attachments", "fileInput"]
  static values = { directUploadsUrl: String }

  connect() {
    this._lifecycleVersion = (this._lifecycleVersion || 0) + 1
    const lifecycleVersion = this._lifecycleVersion
    this.form = this.element.closest("form")
    this.boundOnSubmit = this.#onSubmit.bind(this)
    this.boundFileInputChange = this.#onFileInputChange.bind(this)
    this.#syncFromHidden()
    this.form?.addEventListener("submit", this.boundOnSubmit, { capture: true })
    if (this.hasFileInputTarget) this.fileInputTarget.addEventListener("change", this.boundFileInputChange)
    this.#initEditor(lifecycleVersion)
  }

  disconnect() {
    this._lifecycleVersion = (this._lifecycleVersion || 0) + 1
    this.form?.removeEventListener("submit", this.boundOnSubmit, { capture: true })
    if (this.hasFileInputTarget) this.fileInputTarget.removeEventListener("change", this.boundFileInputChange)
    if (this._fallbackMode && this.textareaTarget) {
      this.textareaTarget.removeEventListener("input", this.#boundOnInput)
      this.textareaTarget.removeEventListener("change", this.#boundOnInput)
    }
    this.#destroyEditor()
  }

  /** Expose EasyMDE instance for markdown-prompt (e.g. @mention insert at cursor). */
  get easymde() {
    return this._easymde ?? null
  }

  #initEditor(lifecycleVersion) {
    if (this._easymde) return
    this.#removeStaleEditorContainers()
    loadEasyMDE()
      .then((EasyMDE) => {
        if (!this.element.isConnected) return
        if (this._lifecycleVersion !== lifecycleVersion) return
        if (this._easymde) return
        this.#removeStaleEditorContainers()
        const placeholder = this.textareaTarget.getAttribute("placeholder") ?? ""
        this._easymde = new EasyMDE({
          element: this.textareaTarget,
          initialValue: this.textareaTarget.value,
          placeholder,
          toolbar: [
            "bold",
            "italic",
            "heading",
            "|",
            "quote",
            "unordered-list",
            "ordered-list",
            "|",
            "link",
            "image",
            "|",
            "preview",
            "side-by-side",
            "fullscreen",
            "|",
            "guide"
          ],
          status: ["lines", "words", "cursor"],
          spellChecker: false,
          forceSync: true,
          autoDownloadFontAwesome: false,
          autofocus: this.textareaTarget.hasAttribute("autofocus")
        })
        this.element.easymde = this._easymde
        this._easymde.codemirror.on("change", () => this.#onEditorChange())
        this._easymde.codemirror.on("keydown", (_, event) => this.#onEditorKeydown(event))
        this.element.dispatchEvent(new CustomEvent("markdown-editor:ready", { bubbles: false }))
      })
      .catch(() => {
        if (this._lifecycleVersion !== lifecycleVersion) return
        this.#fallbackToTextarea()
      })
  }

  #removeStaleEditorContainers() {
    const wrappers = this.element.querySelectorAll(".EasyMDEContainer")
    wrappers.forEach((node) => node.remove())
  }

  #destroyEditor() {
    if (this._easymde) {
      this._easymde.toTextArea()
      this._easymde = null
    }
    if (this.element.easymde) this.element.easymde = null
  }

  #fallbackToTextarea() {
    this._fallbackMode = true
    this.textareaTarget.addEventListener("input", this.#boundOnInput)
    this.textareaTarget.addEventListener("change", this.#boundOnInput)
  }

  get #boundOnInput() {
    if (!this._boundOnInput) this._boundOnInput = this.#onInput.bind(this)
    return this._boundOnInput
  }

  #onInput() {
    this.#dispatchChange(this.textareaTarget.value)
  }

  #onEditorChange() {
    if (!this._easymde) return
    const value = this._easymde.value()
    this.#dispatchChange(value)
  }

  #onEditorKeydown(event) {
    if (!this.#isSubmitShortcut(event)) return
    event.preventDefault()
    event.stopPropagation()
    this.form?.requestSubmit()
  }

  #isSubmitShortcut(event) {
    if (event.isComposing) return false
    const isEnter = event.key === "Enter" || event.code === "Enter" || event.code === "NumpadEnter"
    return isEnter && (event.metaKey || event.ctrlKey)
  }

  #dispatchChange(newContent) {
    this.textareaTarget.dispatchEvent(
      new CustomEvent("editor:change", { bubbles: true, detail: { newContent } })
    )
  }

  #syncFromHidden() {
    const raw = this.hiddenInputTarget.value
    if (raw != null && raw !== "") {
      this.textareaTarget.value = raw
    }
  }

  #onSubmit() {
    const value = this._easymde ? this._easymde.value() : this.textareaTarget.value
    this.hiddenInputTarget.value = value
  }

  /** Set editor content (e.g. after inserting @mention or attachment token). */
  setValue(value) {
    if (this._easymde) {
      this._easymde.value(value)
    } else {
      this.textareaTarget.value = value
      this.textareaTarget.dispatchEvent(new Event("input", { bubbles: true }))
    }
  }

  /** Get current editor content. */
  getValue() {
    return this._easymde ? this._easymde.value() : this.textareaTarget.value
  }

  /** Get cursor position (for textarea fallback: { line, ch } not available, use offset). */
  getCursor() {
    if (this._easymde) return this._easymde.codemirror.getCursor()
    const ta = this.textareaTarget
    const pos = ta.selectionStart
    const before = ta.value.slice(0, pos)
    const line = (before.match(/\n/g) || []).length
    const ch = before.length - before.lastIndexOf("\n") - 1
    return { line, ch }
  }

  /** Open file picker for attachments. */
  uploadFile() {
    if (this.hasFileInputTarget) this.fileInputTarget.click()
  }

  #onFileInputChange(event) {
    const { files } = event.target
    if (!files?.length || !this.hasDirectUploadsUrlValue) return
    const url = this.#directUploadsUrlAbsolute()
    for (const file of Array.from(files)) {
      this.#uploadFile(file, url)
    }
    event.target.value = ""
  }

  #directUploadsUrlAbsolute() {
    const v = this.directUploadsUrlValue
    if (v.startsWith("http")) return v
    return new URL(v, window.location.origin).href
  }

  #uploadFile(file, url) {
    const upload = new DirectUpload(file, url, this)
    upload.create((error, blob) => {
      if (error) return
      const filename = file.name || "file"
      const isImage = (file.type || "").startsWith("image/")
      const token = isImage
        ? `![${filename}](blob-sgid:${blob.signed_id})`
        : `[${filename}](blob-sgid:${blob.signed_id})`
      this.#insertTokenAtCursor(token)
      this.#addAttachmentChip(filename, token)
    })
  }

  #insertTokenAtCursor(token) {
    const value = this.getValue()
    const cursor = this.getCursor()
    if (this._easymde) {
      const cm = this._easymde.codemirror
      const from = cm.getCursor()
      const pos = cm.indexFromPos(from)
      const before = value.slice(0, pos)
      const after = value.slice(pos)
      this.setValue(before + token + after)
      const newPos = cm.posFromIndex(before.length + token.length)
      cm.setCursor(newPos)
      cm.focus()
    } else {
      const ta = this.textareaTarget
      const pos = ta.selectionStart
      const before = value.slice(0, pos)
      const after = value.slice(pos)
      ta.value = before + token + after
      ta.selectionStart = ta.selectionEnd = before.length + token.length
      ta.dispatchEvent(new Event("input", { bubbles: true }))
    }
    this.#dispatchChange(this.getValue())
  }

  #addAttachmentChip(filename, token) {
    if (!this.hasAttachmentsTarget) return
    const chip = document.createElement("span")
    chip.className = "markdown-editor__attachment-chip"
    chip.dataset.token = token
    chip.innerHTML = `<span class="markdown-editor__attachment-name">${this.#escapeHtml(filename)}</span> <button type="button" class="markdown-editor__attachment-remove" data-action="click->markdown-editor#removeAttachment" data-token="${this.#escapeAttr(token)}" aria-label="Remove">×</button>`
    this.attachmentsTarget.appendChild(chip)
  }

  #escapeHtml(s) {
    const div = document.createElement("div")
    div.textContent = s
    return div.innerHTML
  }

  #escapeAttr(s) {
    return s.replace(/&/g, "&amp;").replace(/"/g, "&quot;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
  }

  removeAttachment(event) {
    const btn = event.currentTarget
    const token = btn.dataset.token
    if (!token) return
    const value = this.getValue()
    const next = value.replace(token, "")
    this.setValue(next)
    this.#dispatchChange(next)
    const chip = btn.closest(".markdown-editor__attachment-chip")
    if (chip) chip.remove()
  }

  // DirectUpload delegate (optional)
  directUploadWillStoreFileWithXHR(request) {
    const token = document.querySelector('meta[name="csrf-token"]')?.getAttribute("content")
    if (token) request.setRequestHeader("X-CSRF-Token", token)
  }

  /** Replace range in editor (for textarea: approximate by line/ch). */
  replaceRange(text, from, to) {
    if (this._easymde) {
      this._easymde.codemirror.replaceRange(text, from, to)
      return
    }
    const ta = this.textareaTarget
    const lines = ta.value.split("\n")
    let offset = 0
    for (let i = 0; i < from.line; i++) offset += lines[i].length + 1
    offset += from.ch
    let endOffset = 0
    for (let i = 0; i < (to?.line ?? from.line); i++) endOffset += lines[i].length + 1
    endOffset += (to?.ch ?? from.ch)
    const before = ta.value.slice(0, offset)
    const after = ta.value.slice(endOffset)
    ta.value = before + text + after
    ta.selectionStart = ta.selectionEnd = before.length + text.length
    ta.dispatchEvent(new Event("input", { bubbles: true }))
  }
}
