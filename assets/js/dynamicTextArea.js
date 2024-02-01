const DynamicTextArea = {
  mounted() {
    setHeight(this.el);

    this.el.addEventListener('input', () => {
      setHeight(this.el);
    });
  }
}

const setHeight = (textArea) => {
  textArea.style.height = "0px";
  const contentHeight = textArea.scrollHeight;

  // we need to add 2px to the height to avoid the scrollbar
  textArea.style.height = `${contentHeight + 2}px`;
}

export default DynamicTextArea;