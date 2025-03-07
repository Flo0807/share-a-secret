export default {
  mounted () {
    this.resize()

    this.el.addEventListener('input', this.resize.bind(this))
    this.el.addEventListener('change', this.resize.bind(this))
  },
  updated () {
    this.resize()
  },
  beforeDestroy () {
    this.el.removeEventListener('input', this.resize.bind(this))
    this.el.removeEventListener('change', this.resize.bind(this))
  },
  resize () {
    this.el.style.height = '0'

    // Add 2px to prevent scrollbar
    const contentHeight = this.el.scrollHeight + 2

    const minHeight = parseInt(this.el.dataset.minHeight || 40, 10)
    const finalHeight = Math.max(contentHeight, minHeight)

    this.el.style.height = `${finalHeight}px`
  }
}
