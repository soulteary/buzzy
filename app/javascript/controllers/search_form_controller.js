import { Controller } from "@hotwired/stimulus"

// 与 MySQL ngram 全文检索一致：至少 2 个字符才发起搜索，避免单字无法命中
const DEFAULT_MIN_LENGTH = 2

export default class extends Controller {
  static targets = [ "input" ]
  static values = {
    minLength: { type: Number, default: DEFAULT_MIN_LENGTH },
  }

  preventSubmitIfTooShort(event) {
    const query = this.inputTarget.value?.trim() ?? ""
    if (query.length < this.minLengthValue) {
      event.preventDefault()
    }
  }
}
