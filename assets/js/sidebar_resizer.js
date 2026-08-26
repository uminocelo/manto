const WIDTH_KEY = "manto:sidebar-width"
const DEFAULT_WIDTH = 256 // 16rem = w-64

const SidebarResizer = {
  mounted() {
    this.restoreWidth()

    this.handle = this.el.querySelector("#sidebar-resize-handle")
    if (!this.handle) return

    this.onMouseDown = (e) => {
      e.preventDefault()
      this.startX = e.clientX
      this.startWidth = this.el.offsetWidth
      document.addEventListener("mousemove", this.onMouseMove)
      document.addEventListener("mouseup", this.onMouseUp)
      document.body.style.cursor = "col-resize"
      document.body.style.userSelect = "none"
    }

    this.onMouseMove = (e) => {
      const delta = e.clientX - this.startX
      const newWidth = Math.max(160, Math.min(480, this.startWidth + delta))
      this.el.style.width = newWidth + "px"
    }

    this.onMouseUp = () => {
      document.removeEventListener("mousemove", this.onMouseMove)
      document.removeEventListener("mouseup", this.onMouseUp)
      document.body.style.cursor = ""
      document.body.style.userSelect = ""
      try {
        window.localStorage.setItem(WIDTH_KEY, this.el.style.width || String(this.el.offsetWidth) + "px")
      } catch (_error) {
        // ignore
      }
    }

    this.handle.addEventListener("mousedown", this.onMouseDown)
  },

  destroyed() {
    if (this.handle) {
      this.handle.removeEventListener("mousedown", this.onMouseDown)
    }
    document.removeEventListener("mousemove", this.onMouseMove)
    document.removeEventListener("mouseup", this.onMouseUp)
  },

  restoreWidth() {
    let stored
    try {
      stored = window.localStorage.getItem(WIDTH_KEY)
    } catch (_error) {
      return
    }
    if (stored) {
      this.el.style.width = stored
    }
  },
}

export {SidebarResizer}