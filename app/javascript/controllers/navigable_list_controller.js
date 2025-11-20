import { Controller } from "@hotwired/stimulus"
import { nextFrame } from "helpers/timing_helpers"

export default class extends Controller {
  static targets = [ "item", "input" ]
  static values = {
    reverseOrder: { type: Boolean, default: false },
    selectionAttribute: { type: String, default: "aria-selected" },
    focusOnSelection: { type: Boolean, default: true },
    actionableItems: { type: Boolean, default: false },
    reverseNavigation: { type: Boolean, default: false },
    supportHorizontalNavigation: { type: Boolean, default: true },
    supportVerticalNavigation: { type: Boolean, default: true },
    hasNestedNavigation: { type: Boolean, default: false },
    preventHandledKeys: { type: Boolean, default: false },
    autoSelect: { type: Boolean, default: true }
  }

  connect() {
    if (this.autoSelectValue) {
      this.reset()
    } else {
      this.#activateManualSelection()
    }
  }

  // Actions

  reset(event) {
    if (this.reverseOrderValue) {
      this.selectLast()
    } else {
      this.selectFirst()
    }
  }

  navigate(event) {
    console.debug("PRESSED", this.element);
    this.#keyHandlers[event.key]?.call(this, event)

    const parentNavigableList = this.element.parentElement?.closest('[data-controller~="navigable-list"]')
    if (parentNavigableList) {
      const parentController = this.application.getControllerForElementAndIdentifier(parentNavigableList, "navigable-list")
      if (parentController) {
        console.debug("CALLED!");
        parentNavigableList.focus()
        parentController.navigate(event)
      }
    }
  }

  select({ target }) {
    this.#setCurrentFrom(target)
  }

  selectCurrentOrReset(event) {
    if (this.currentItem) {
      this.#setCurrentFrom(this.currentItem)
    } else {
      this.reset()
    }
  }

  selectFirst() {
    this.#setCurrentFrom(this.#visibleItems[0])
  }

  selectLast() {
    this.#setCurrentFrom(this.#visibleItems[this.#visibleItems.length - 1])
  }

  // Private

  get #visibleItems() {
    return this.itemTargets.filter(item => {
      return item.checkVisibility() && !item.hidden
    })
  }

  #selectPrevious() {
    const index = this.#visibleItems.indexOf(this.currentItem)
    if (index > 0) {
      this.#setCurrentFrom(this.#visibleItems[index - 1])
    }
  }

  #selectNext() {
    const index = this.#visibleItems.indexOf(this.currentItem)
    if (index >= 0 && index < this.#visibleItems.length - 1) {
      this.#setCurrentFrom(this.#visibleItems[index + 1])
    }
  }

  async #setCurrentFrom(element) {
    const selectedItem = this.#visibleItems.find(item => item.contains(element))

    if (selectedItem) {
      await this.#selectItem(selectedItem)
    }
  }

  async #selectItem(item) {
    this.#clearSelection()
    item.setAttribute(this.selectionAttributeValue, "true")
    this.currentItem = item

    await nextFrame()

    this.#scrollAndFocusOnSelectedItem()
  }

  #scrollAndFocusOnSelectedItem() {
    const id = this.currentItem?.getAttribute("id")
    this.currentItem.scrollIntoView({ block: "nearest", inline: "nearest" })
  console.debug("this.currentItem", this.currentItem);
    if (this.hasNestedNavigationValue) {
      this.#activateNestedNavigableList()
    }

    if (this.focusOnSelectionValue) { this.currentItem.focus() }
    if (this.hasInputTarget && id) {
      this.inputTarget.setAttribute("aria-activedescendant", id)
    }

  }

  #clearSelection() {
    for (const item of this.itemTargets) {
      item.removeAttribute(this.selectionAttributeValue)
    }
  }

  #activateManualSelection() {
    const preselectedItem = this.itemTargets.find(item => item.hasAttribute(this.selectionAttributeValue))
    if (preselectedItem) {
      this.#setCurrentFrom(preselectedItem)
    }
  }

  #handleArrowKey(event, fn) {
    if (event.shiftKey || event.metaKey || event.ctrlKey) { return }
    fn.call()
    if (this.preventHandledKeysValue) {
      event.preventDefault()
    }
  }

  #clickCurrentItem(event) {
    if (this.actionableItemsValue && this.currentItem && this.#visibleItems.length) {
      const clickableElement = this.currentItem.querySelector("a,button") || this.currentItem
      clickableElement.click()
      event.preventDefault()
    }
  }

  #toggleCurrentItem(event) {
    if (this.actionableItemsValue && this.currentItem && this.#visibleItems.length) {
      const toggleable = this.currentItem.querySelector("input[type=checkbox]")
      const isDisabled = toggleable.hasAttribute("disabled")

      if (toggleable) {
        if (!isDisabled) {
          toggleable.checked = !toggleable.checked
          toggleable.dispatchEvent(new Event('change', { bubbles: true }))
        }
        event.preventDefault()
      }
    }
  }

  #activateNestedNavigableList() {
    const nestedController = this.#findNestedNavigableListController()
    if (nestedController) {
      console.debug("CALLED!", this.element);
      nestedController.reset()
      return true
    }
    return false
  }

  #findNestedNavigableListController() {
    const nestedElement = this.currentItem?.querySelector('[data-controller~="navigable-list"]')
    if (nestedElement) {
      return this.application.getControllerForElementAndIdentifier(nestedElement, "navigable-list")
    }
    return null
  }

  #keyHandlers = {
    ArrowDown(event) {
      if (this.supportVerticalNavigationValue) {
        const selectMethod = this.reverseNavigationValue ? this.#selectPrevious.bind(this) : this.#selectNext.bind(this)
        this.#handleArrowKey(event, selectMethod)
      }
    },
    ArrowUp(event) {
      if (this.supportVerticalNavigationValue) {
        const selectMethod = this.reverseNavigationValue ? this.#selectNext.bind(this) : this.#selectPrevious.bind(this)
        this.#handleArrowKey(event, selectMethod)
      }
    },
    ArrowRight(event) {
      if (this.supportHorizontalNavigationValue) {
        this.#handleArrowKey(event, this.#selectNext.bind(this))
      }
    },
    ArrowLeft(event) {
      if (this.supportHorizontalNavigationValue) {
        this.#handleArrowKey(event, this.#selectPrevious.bind(this))
      }
    },
    Enter(event) {
      if (event.shiftKey) {
        this.#toggleCurrentItem(event)
      } else {
        this.#clickCurrentItem(event)
      }
    },
  }
}
