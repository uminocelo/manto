const DragDrop = {
  mounted() {
    this.onDragStart = (e) => {
      const page = e.target.closest("[data-drag-page]")
      const folder = e.target.closest("[data-drag-folder]")
      if (page) {
        e.dataTransfer.setData("text/plain", JSON.stringify({type: "page", slug: page.dataset.dragPage}))
        e.dataTransfer.effectAllowed = "move"
      } else if (folder) {
        e.dataTransfer.setData("text/plain", JSON.stringify({type: "folder", slug: folder.dataset.dragFolder}))
        e.dataTransfer.effectAllowed = "move"
      } else {
        e.preventDefault()
      }
    }

    this.onDragOver = (e) => {
      const target = e.target.closest("[data-drop-folder]")
      if (!target) return
      e.preventDefault()
      e.dataTransfer.dropEffect = "move"
      target.classList.add("bg-indigo-100", "dark:bg-indigo-900")
    }

    this.onDragLeave = (e) => {
      const target = e.target.closest("[data-drop-folder]")
      if (!target) return
      target.classList.remove("bg-indigo-100", "dark:bg-indigo-900")
    }

    this.onDrop = (e) => {
      const target = e.target.closest("[data-drop-folder]")
      if (!target) return
      e.preventDefault()
      target.classList.remove("bg-indigo-100", "dark:bg-indigo-900")

      let data
      try {
        data = JSON.parse(e.dataTransfer.getData("text/plain"))
      } catch {
        return
      }
      if (!data) return

      const targetFolder = target.dataset.dropFolder

      if (data.type === "page") {
        this.pushEvent("move_page", {page: data.slug, target_folder: targetFolder})
      } else if (data.type === "folder") {
        this.pushEvent("move_folder", {folder: data.slug, target_folder: targetFolder})
      }
    }

    this.el.addEventListener("dragstart", this.onDragStart)
    this.el.addEventListener("dragover", this.onDragOver)
    this.el.addEventListener("dragleave", this.onDragLeave)
    this.el.addEventListener("drop", this.onDrop)
  },

  destroyed() {
    this.el.removeEventListener("dragstart", this.onDragStart)
    this.el.removeEventListener("dragover", this.onDragOver)
    this.el.removeEventListener("dragleave", this.onDragLeave)
    this.el.removeEventListener("drop", this.onDrop)
  },
}

export {DragDrop}