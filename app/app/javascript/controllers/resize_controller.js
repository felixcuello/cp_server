import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="resize"
export default class extends Controller {
  static targets = ["leftPane", "rightPane", "resizer", "leftTopPane", "leftBottomPane", "leftVerticalResizer"]
  
  connect() {
    // Horizontal resize (between left pane and editor)
    if (this.hasResizerTarget && this.hasLeftPaneTarget && this.hasRightPaneTarget) {
      this.setupHorizontalResize()
    }
    
    // Vertical resize in left pane (between description and test results)
    if (this.hasLeftVerticalResizerTarget && this.hasLeftTopPaneTarget && this.hasLeftBottomPaneTarget) {
      this.setupLeftPaneVerticalResize()
      this.watchTestResultsVisibility()
    }
  }
  
  watchTestResultsVisibility() {
    // Watch for changes to test results container visibility
    if (!this.hasLeftBottomPaneTarget) return
    
    const testResultsContainer = this.leftBottomPaneTarget
    
    // Initial check
    this.updateLeftVerticalResizerVisibility()
    
    // Watch for style changes using MutationObserver
    const observer = new MutationObserver(() => {
      this.updateLeftVerticalResizerVisibility()
    })
    
    observer.observe(testResultsContainer, {
      attributes: true,
      attributeFilter: ['style']
    })
  }
  
  updateLeftVerticalResizerVisibility() {
    if (!this.hasLeftBottomPaneTarget || !this.hasLeftVerticalResizerTarget) return
    
    const testResultsContainer = this.leftBottomPaneTarget
    const resizer = this.leftVerticalResizerTarget
    const isVisible = testResultsContainer.style.display !== 'none' && 
                      window.getComputedStyle(testResultsContainer).display !== 'none'
    
    if (isVisible) {
      resizer.style.display = 'block'
      // When test results become visible, set initial split (60% description, 40% results)
      if (!this.leftTopPaneTarget.style.flex) {
        this.leftTopPaneTarget.style.flex = '0 0 60%'
        testResultsContainer.style.flex = '1'
      }
    } else {
      resizer.style.display = 'none'
      // When hidden, let description take full space
      this.leftTopPaneTarget.style.flex = '1'
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
  
  setupLeftPaneVerticalResize() {
    const resizer = this.leftVerticalResizerTarget
    const topPane = this.leftTopPaneTarget
    const bottomPane = this.leftBottomPaneTarget
    
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
      const minHeight = 150  // Minimum height for description
      const maxHeight = containerHeight - 150 - resizerHeight  // Leave room for test results
      
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
