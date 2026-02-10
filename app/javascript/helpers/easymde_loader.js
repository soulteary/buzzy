/**
 * Loads EasyMDE and CodeMirror from local static assets (UMD). Returns a Promise
 * that resolves to the EasyMDE constructor. Used by markdown_editor_controller
 * for EasyMDE integration.
 */
const CODEMIRROR_JS = "/vendor/codemirror/5.65.16/codemirror.min.js"
const CODEMIRROR_CSS = "/vendor/codemirror/5.65.16/codemirror.min.css"
const EASYMDE_JS = "/vendor/easymde/2.18.0/easymde.min.js"
const EASYMDE_CSS = "/vendor/easymde/2.18.0/easymde.min.css"
const FONT_AWESOME_CSS = "/vendor/font-awesome/4.7.0/css/font-awesome.min.css"

function loadScript(src) {
  return new Promise((resolve, reject) => {
    if (document.querySelector(`script[src="${src}"]`)) {
      resolve()
      return
    }
    const s = document.createElement("script")
    s.src = src
    s.async = false
    s.onload = () => resolve()
    s.onerror = () => reject(new Error(`Failed to load ${src}`))
    document.head.appendChild(s)
  })
}

function loadCSS(href) {
  if (document.querySelector(`link[href="${href}"]`)) return
  const link = document.createElement("link")
  link.rel = "stylesheet"
  link.href = href
  document.head.appendChild(link)
}

export default function loadEasyMDE() {
  if (typeof window.EasyMDE === "function") {
    loadCSS(CODEMIRROR_CSS)
    loadCSS(EASYMDE_CSS)
    loadCSS(FONT_AWESOME_CSS)
    return Promise.resolve(window.EasyMDE)
  }
  loadCSS(CODEMIRROR_CSS)
  loadCSS(EASYMDE_CSS)
  loadCSS(FONT_AWESOME_CSS)
  return loadScript(CODEMIRROR_JS).then(() => loadScript(EASYMDE_JS)).then(() => window.EasyMDE)
}
