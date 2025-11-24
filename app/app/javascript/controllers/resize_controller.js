import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="resize"
export default class extends Controller {
  static targets = ["leftPane", "rightPane", "resizer", "topPane", "bottomPane", "verticalResizer"]
  
  connect() {
    // Horizontal resize (between description and editor)
    if (this.hasResizerTarget && this.hasLeftPaneTarget && this.hasRightPaneTarget) {
      this.setupHorizontalResize()
    }
    
    // Vertical resize (between editor and test results)
    if (this.hasVerticalResizerTarget && this.hasTopPaneTarget && this.hasBottomPaneTarget) {
      this.setupVerticalResize()
      this.watchTestResultsVisibility()
    }
  }
  
  watchTestResultsVisibility() {
    // Watch for changes to test results container visibility
    if (!this.hasBottomPaneTarget) return
    
    const testResultsContainer = this.bottomPaneTarget
    const resizer = this.verticalResizerTarget
    
    // Initial check
    this.updateVerticalResizerVisibility()
    
    // Watch for style changes using MutationObserver
    const observer = new MutationObserver(() => {
      this.updateVerticalResizerVisibility()
    })
    
    observer.observe(testResultsContainer, {
      attributes: true,
      attributeFilter: ['style']
    })
  }
  
  updateVerticalResizerVisibility() {
    if (!this.hasBottomPaneTarget || !this.hasVerticalResizerTarget) return
    
    const testResultsContainer = this.bottomPaneTarget
    const resizer = this.verticalResizerTarget
    const isVisible = testResultsContainer.style.display !== 'none' && 
                      window.getComputedStyle(testResultsContainer).display !== 'none'
    
    if (isVisible) {
      resizer.style.display = 'block'
    } else {
      resizer.style.display = 'none'
    }
  }
  
  setupHorizontalResize() {
    const resizer = this.resizerTarget
    const leftPane = this.leftPaneTarget
    const rightPane = this.rightPaneTarget
    
    let isResizing = false
    let startX = 0
    let startLeftWidth = 0
    
    resizer.addEventListener('mousedown', (e) => {
      isResizing = true
      startX = e.clientX
      startLeftWidth = leftPane.offsetWidth
      document.body.style.cursor = 'col-resize'
      document.body.style.userSelect = 'none'
      e.preventDefault()
    })
    
    document.addEventListener('mousemove', (e) => {
      if (!isResizing) return
      
      const container = leftPane.parentElement
      const containerWidth = container.offsetWidth
      const resizerWidth = resizer.offsetWidth
      const deltaX = e.clientX - startX
      
      // Calculate new width as percentage
      const newLeftWidth = startLeftWidth + deltaX
      const minWidth = 300
      const maxWidth = containerWidth - 300 - resizerWidth
      
      if (newLeftWidth >= minWidth && newLeftWidth <= maxWidth) {
        const percentage = (newLeftWidth / containerWidth) * 100
        leftPane.style.flex = `0 0 ${percentage}%`
        rightPane.style.flex = '1'
      }
    })
    
    document.addEventListener('mouseup', () => {
      if (isResizing) {
        isResizing = false
        document.body.style.cursor = ''
        document.body.style.userSelect = ''
      }
    })
  }
  
  setupVerticalResize() {
    const resizer = this.verticalResizerTarget
    const topPane = this.topPaneTarget
    const bottomPane = this.bottomPaneTarget
    
    let isResizing = false
    let startY = 0
    let startTopHeight = 0
    
    resizer.addEventListener('mousedown', (e) => {
      isResizing = true
      startY = e.clientY
      startTopHeight = topPane.offsetHeight
      document.body.style.cursor = 'row-resize'
      document.body.style.userSelect = 'none'
      e.preventDefault()
    })
    
    document.addEventListener('mousemove', (e) => {
      if (!isResizing) return
      
      const container = topPane.parentElement
      const containerHeight = container.offsetHeight
      const resizerHeight = resizer.offsetHeight
      const deltaY = e.clientY - startY
      
      // Calculate new height
      const newTopHeight = startTopHeight + deltaY
      const minHeight = 300
      const maxHeight = containerHeight - 200 - resizerHeight
      
      if (newTopHeight >= minHeight && newTopHeight <= maxHeight) {
        const percentage = (newTopHeight / containerHeight) * 100
        topPane.style.flex = `0 0 ${percentage}%`
        bottomPane.style.flex = '1'
      }
    })
    
    document.addEventListener('mouseup', () => {
      if (isResizing) {
        isResizing = false
        document.body.style.cursor = ''
        document.body.style.userSelect = ''
      }
    })
  }
}
