export default {
  mounted () {
    this.onResize = () => this.resize()
    this.resize()

    this.el.addEventListener('input', this.onResize)
    this.el.addEventListener('change', this.onResize)
  },
  updated () {
    this.resize()
  },
  destroyed () {
    this.el.removeEventListener('input', this.onResize)
    this.el.removeEventListener('change', this.onResize)
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
