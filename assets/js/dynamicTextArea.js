const DynamicTextArea = {
  mounted () {
    const defaultHeight = this.el.dataset.defaultHeight

    setHeight(this.el, defaultHeight)

    this.el.addEventListener('input', () => {
      setHeight(this.el, defaultHeight)
    })
  }
}

const setHeight = (textArea, defaultHeight) => {
  textArea.style.height = `${defaultHeight}px`

  const contentHeight = textArea.scrollHeight

  if (contentHeight > defaultHeight) {
    // we need to add 2px to the height to avoid the scrollbar
    textArea.style.height = `${contentHeight + 2}px`
  }
}

export default DynamicTextArea
