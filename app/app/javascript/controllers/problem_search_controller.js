import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="problem-search"
export default class extends Controller {
  static targets = ["input", "row"]
  static values = { delay: { type: Number, default: 300 } }
  
  connect() {
    this.timeout = null
  }
  
  search() {
    // Clear existing timeout
    clearTimeout(this.timeout)
    
    // Debounce the search
    this.timeout = setTimeout(() => {
      this.performSearch()
    }, this.delayValue)
  }
  
  performSearch() {
    const query = this.inputTarget.value.toLowerCase().trim()
    
    this.rowTargets.forEach(row => {
      const title = row.dataset.problemTitle?.toLowerCase() || ''
      const id = row.dataset.problemId?.toLowerCase() || ''
      const tags = row.dataset.problemTags?.toLowerCase() || ''
      
      const matches = title.includes(query) || 
                     id.includes(query) || 
                     tags.includes(query) ||
                     query === ''
      
      // Use data attribute to mark search state (for pagination coordination)
      if (matches) {
        delete row.dataset.searchedOut
      } else {
        row.dataset.searchedOut = 'true'
      }
    })
    
    // Dispatch event for pagination to update
    this.element.dispatchEvent(new CustomEvent('search:changed', { bubbles: true }))
  }
  
  clear() {
    this.inputTarget.value = ''
    this.performSearch()
  }
}
