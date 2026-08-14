const STORAGE_PREFIX = "manto:draft:"
const CONFIRM_MESSAGE = "You have unsaved changes. Are you sure you want to leave this page?"

const EditorGuard = {
  mounted() {
    this.serverBody = this.getValue()
    this.dirty = false
    this.autosaveTimer = null

    this.onInput = () => {
      this.dirty = this.getValue() !== this.serverBody
      this.scheduleAutosave()
    }
    this.el.addEventListener("input", this.onInput)

    this.onBeforeUnload = (event) => {
      if (this.dirty) {
        event.preventDefault()
        event.returnValue = ""
      }
    }
    window.addEventListener("beforeunload", this.onBeforeUnload)

    this.onClick = (event) => {
      const link = event.target.closest("a[data-phx-link]")
      if (link && this.dirty && !window.confirm(CONFIRM_MESSAGE)) {
        event.preventDefault()
        event.stopImmediatePropagation()
      }
    }
    document.addEventListener("click", this.onClick, true)

    this.onSubmit = (event) => {
      const form = event.target.closest("form[phx-submit]")
      const isSave = form && form.getAttribute("phx-submit") === "save"
      if (form && !isSave && this.dirty && !window.confirm(CONFIRM_MESSAGE)) {
        event.preventDefault()
        event.stopImmediatePropagation()
      }
    }
    document.addEventListener("submit", this.onSubmit, true)

    this.onDraftSaved = () => {
      this.serverBody = this.getValue()
      this.dirty = false
      this.clearDraft()
    }
    this.handleEvent("draft_saved", this.onDraftSaved)

    this.restoreDraft()
  },

  destroyed() {
    window.removeEventListener("beforeunload", this.onBeforeUnload)
    document.removeEventListener("click", this.onClick, true)
    document.removeEventListener("submit", this.onSubmit, true)
    clearTimeout(this.autosaveTimer)
  },

  getValue() {
    const textarea = this.el.querySelector("textarea[name=markdown]")
    return textarea ? textarea.value : ""
  },

  scheduleAutosave() {
    clearTimeout(this.autosaveTimer)
    this.autosaveTimer = setTimeout(() => this.writeDraft(this.getValue()), 400)
  },

  restoreDraft() {
    const draft = this.readDraft()
    if (draft && draft !== this.getValue()) {
      this.setValue(draft)
      this.dirty = true
      this.pushEvent("restore_draft", {body: draft})
    }
  },

  storageKey() {
    return STORAGE_PREFIX + this.el.dataset.page
  },

  readDraft() {
    try {
      return window.localStorage.getItem(this.storageKey())
    } catch (_error) {
      return null
    }
  },

  writeDraft(body) {
    try {
      window.localStorage.setItem(this.storageKey(), body)
    } catch (_error) {
      // storage unavailable (private mode, quota); autosave is best-effort
    }
  },

  clearDraft() {
    try {
      window.localStorage.removeItem(this.storageKey())
    } catch (_error) {
      // ignore
    }
  },

  setValue(value) {
    const textarea = this.el.querySelector("textarea[name=markdown]")
    if (textarea) {
      textarea.value = value
    }
  },
}

export {EditorGuard}
