const STORAGE_KEY = "manto:collapsed"

const CollapseGuard = {
  mounted() {
    // Restore collapsed state from localStorage on mount
    this.restoreCollapsed()

    // Listen for server events to persist collapse state
    this.handleEvent("persist_collapse", ({collapsed_folders}) => {
      try {
        window.localStorage.setItem(STORAGE_KEY, JSON.stringify(collapsed_folders))
      } catch (_error) {
        // storage unavailable
      }
    })
  },

  restoreCollapsed() {
    let stored
    try {
      stored = window.localStorage.getItem(STORAGE_KEY)
    } catch (_error) {
      return
    }
    if (!stored) return
    try {
      const folders = JSON.parse(stored)
      if (Array.isArray(folders) && folders.length > 0) {
        this.pushEvent("restore_collapsed", {folders})
      }
    } catch (_error) {
      // invalid JSON, ignore
    }
  },
}

export {CollapseGuard}