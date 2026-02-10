import { Controller } from "@hotwired/stimulus"
import { differenceInDays, secondsToDate } from "helpers/date_helpers"

const DEFAULT_LOCALE = "en-US"

function localeForIntl() {
  const el = document.getElementById("local-time-strings")
  const locale = el?.dataset?.locale || (typeof window.localTimeLocale === "string" ? window.localTimeLocale : document.documentElement?.lang || "en")
  if (locale.startsWith("zh")) return "zh-CN"
  return locale
}

export default class extends Controller {
  static targets = [ "time", "date", "datetime", "shortdate", "ago", "indays", "daysago", "agoorweekday", "timeordate" ]
  static values = { refreshInterval: Number }
  static classes = [ "local-time-value"]

  #timer

  initialize() {
    const locale = localeForIntl()
    this.timeFormatter = new Intl.DateTimeFormat(locale, { timeStyle: "short" })
    this.dateFormatter = new Intl.DateTimeFormat(locale, { dateStyle: "long" })
    this.shortdateFormatter = new Intl.DateTimeFormat(locale, { month: "short", day: "numeric" })
    this.datetimeFormatter = new Intl.DateTimeFormat(locale, { timeStyle: "short", dateStyle: "short" })
    this.agoFormatter = new AgoFormatter()
    this.daysagoFormatter = new DaysAgoFormatter()
    this.datewithweekdayFormatter = new Intl.DateTimeFormat(locale, { weekday: "long", month: "long", day: "numeric" })
    this.indaysFormatter = new InDaysFormatter()
    this.agoorweekdayFormatter = new DaysAgoOrWeekdayFormatter(locale)
    this.timeordateFormatter = new TimeOrDateFormatter(locale)
  }

  connect() {
    this.#timer = setInterval(() => this.#refreshRelativeTimes(), 30_000)
  }

  disconnect() {
    clearInterval(this.#timer)
  }

  refreshAll() {
    this.constructor.targets.forEach(targetName => {
      this.targets.findAll(targetName).forEach(target => {
        this.#formatTime(this[`${targetName}Formatter`], target)
      })
    })
  }

  refreshTarget(event) {
    const root = event.target
    const target = root.dataset?.localTimeTarget ? root : root.querySelector?.("[data-local-time-target]")
    if (!target) return
    const targetName = target.dataset.localTimeTarget
    const formatter = targetName ? this[`${targetName}Formatter`] : undefined
    if (!formatter?.format) return
    this.#formatTime(formatter, target)
  }

  timeTargetConnected(target) {
    this.#formatTime(this.timeFormatter, target)
  }

  dateTargetConnected(target) {
    this.#formatTime(this.dateFormatter, target)
  }

  datetimeTargetConnected(target) {
    this.#formatTime(this.datetimeFormatter, target)
  }

  shortdateTargetConnected(target) {
    this.#formatTime(this.shortdateFormatter, target)
  }

  agoTargetConnected(target) {
    this.#formatTime(this.agoFormatter, target)
  }

  indaysTargetConnected(target) {
    this.#formatTime(this.indaysFormatter, target)
  }

  daysagoTargetConnected(target) {
    this.#formatTime(this.daysagoFormatter, target)
  }

  agoorweekdayTargetConnected(target) {
    this.#formatTime(this.agoorweekdayFormatter, target)
  }

  timeordateTargetConnected(target) {
    this.#formatTime(this.timeordateFormatter, target)
  }

  #refreshRelativeTimes() {
    this.agoTargets.forEach(target => {
      this.#formatTime(this.agoFormatter, target)
    })
  }

  #formatTime(formatter, target) {
    if (!formatter?.format) return
    const datetime = target.getAttribute("datetime")
    if (datetime == null || datetime === "") return
    const dt = secondsToDate(parseInt(datetime, 10))
    if (Number.isNaN(dt?.getTime())) return
    target.innerHTML = formatter.format(dt)
    if (this.datetimeFormatter) target.title = this.datetimeFormatter.format(dt)
  }
}

class AgoFormatter {
  format(dt) {
    const now = new Date()
    const seconds = (now - dt) / 1000
    const minutes = seconds / 60
    const hours = minutes / 60
    const days = hours / 24
    const weeks = days / 7
    const months = days / (365 / 12)
    const years = days / 365

    if (years >= 1) return this.#pluralize("year", years)
    if (months >= 1) return this.#pluralize("month", months)
    if (weeks >= 1) return this.#pluralize("week", weeks)
    if (days >= 1) return this.#pluralize("day", days)
    if (hours >= 1) return this.#pluralize("hour", hours)
    if (minutes >= 1) return this.#pluralize("minute", minutes)

    return "Less than a minute ago"
  }

  #pluralize(word, quantity) {
    quantity = Math.floor(quantity)
    const suffix = (quantity === 1) ? "" : "s"
    return `${quantity} ${word}${suffix} ago`
  }
}

function relativeTimeStrings() {
  const el = document.getElementById("local-time-strings")
  if (el?.textContent) {
    try {
      const parsed = JSON.parse(el.textContent)
      if (parsed && typeof parsed === "object") {
        return parsed
      }
    } catch (_) {}
  }
  return typeof window.localTimeStrings === "object" && window.localTimeStrings
    ? window.localTimeStrings
    : { today: "today", yesterday: "yesterday", tomorrow: "tomorrow", in_days: "in %{count} days", days_ago: "%{count} days ago" }
}

class DaysAgoFormatter {
  format(date) {
    const days = differenceInDays(date, new Date())
    const strings = relativeTimeStrings()

    if (days <= 0) return styleableValue(strings.today || "today")
    if (days === 1) return styleableValue(strings.yesterday || "yesterday")
    const template = strings.days_ago || "%{count} days ago"
    return template.replace(/%\{count\}/g, styleableValue(days))
  }
}

class DaysAgoOrWeekdayFormatter {
  constructor(locale = DEFAULT_LOCALE) {
    this.locale = locale
  }

  format(date) {
    const days = differenceInDays(date, new Date())

    if (days <= 1) {
      return new DaysAgoFormatter().format(date)
    } else {
      return new Intl.DateTimeFormat(this.locale, { weekday: "long", month: "long", day: "numeric" }).format(date)
    }
  }
}

class InDaysFormatter {
  format(date) {
    const days = differenceInDays(new Date(), date)
    const strings = relativeTimeStrings()

    if (days <= 0) return styleableValue(strings.today || "today")
    if (days === 1) return styleableValue(strings.tomorrow || "tomorrow")
    const template = strings.in_days || "in %{count} days"
    return template.replace(/%\{count\}/g, styleableValue(days))
  }
}

class TimeOrDateFormatter {
  constructor(locale = DEFAULT_LOCALE) {
    this.locale = locale
  }

  format(date) {
    const days = differenceInDays(date, new Date())

    if (days >= 1) {
      return new Intl.DateTimeFormat(this.locale, { month: "short", day: "numeric" }).format(date)
    } else {
      return new Intl.DateTimeFormat(this.locale, { timeStyle: "short" }).format(date)
    }
  }
}

function styleableValue(value) {
  return `<span class="local-time-value">${value}</span>`
}
