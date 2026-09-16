const SyncPreviewFrame = {
  mounted() {
    this.updateSrcDoc()
  },
  updated() {
    this.updateSrcDoc()
  },
  updateSrcDoc() {
    const srcdoc = this.el.getAttribute("srcdoc")
    if (srcdoc) {
      this.el.src = "data:text/html;charset=utf-8," + encodeURIComponent(srcdoc)
    }
  },
}

export {SyncPreviewFrame}