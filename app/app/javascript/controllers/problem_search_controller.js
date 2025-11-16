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
      
      if (matches) {
        row.style.display = ''
      } else {
        row.style.display = 'none'
      }
    })
    
    this.updateEmptyState()
  }
  
  clear() {
    this.inputTarget.value = ''
    this.performSearch()
  }
  
  updateEmptyState() {
    const visibleRows = this.rowTargets.filter(row => row.style.display !== 'none')
    
    // You can add an empty state message if needed
    if (visibleRows.length === 0) {
      console.log('No problems found')
    }
  }
}
