const ShadowPreview = {
  mounted() {
    this.renderContent()
  },
  updated() {
    this.renderContent()
  },
  renderContent() {
    const html = this.el.getAttribute("data-preview-html")
    if (!html) return

    // Clear any existing shadow root
    if (this._shadowRoot) {
      this._shadowRoot.innerHTML = ""
    } else {
      this._shadowRoot = this.el.attachShadow({mode: "open"})
    }

    // Inject the preview content directly into the shadow DOM.
    // Links work naturally — clicking <a href="/editor/Slug"> navigates the
    // top-level page (the editor) because the shadow DOM is part of the main
    // document, not an isolated iframe.
    this._shadowRoot.innerHTML = html
  },
}

export {ShadowPreview}