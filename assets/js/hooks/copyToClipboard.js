const copyEvent = 'share-secret:copy-to-clipboard'

export default {
  mounted () {
    this.copying = false

    this.handleCopy = async event => {
      if (this.copying) return

      const source = document.getElementById(event.detail.sourceId)

      if (!source || !navigator.clipboard) return

      this.copying = true

      try {
        await navigator.clipboard.writeText(source.value)
        this.js().exec(this.el.dataset.copySuccess)

        this.resetTimer = window.setTimeout(() => {
          this.js().exec(this.el.dataset.copyReset)
          this.copying = false
          this.resetTimer = undefined
        }, Number.parseInt(this.el.dataset.copyDuration, 10))
      } catch (error) {
        this.copying = false
        console.error('Unable to copy to clipboard', error)
      }
    }

    this.el.addEventListener(copyEvent, this.handleCopy)
  },

  destroyed () {
    this.el.removeEventListener(copyEvent, this.handleCopy)
    window.clearTimeout(this.resetTimer)
  }
}
