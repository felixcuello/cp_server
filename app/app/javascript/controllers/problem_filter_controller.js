import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="problem-filter"
export default class extends Controller {
  static targets = ["row", "difficultyCheckbox", "tagCheckbox", "statusCheckbox", "clearButton"]
  
  filter() {
    const selectedDifficulties = this.getSelectedValues(this.difficultyCheckboxTargets)
    const selectedTags = this.getSelectedValues(this.tagCheckboxTargets)
    const selectedStatuses = this.getSelectedValues(this.statusCheckboxTargets)
    
    this.rowTargets.forEach(row => {
      const difficulty = row.dataset.problemDifficulty
      const tags = row.dataset.problemTags?.split(',') || []
      const status = row.dataset.problemStatus
      
      const matchesDifficulty = selectedDifficulties.length === 0 || 
                               selectedDifficulties.includes(difficulty)
      
      const matchesTags = selectedTags.length === 0 || 
                         selectedTags.some(tag => tags.includes(tag))
      
      const matchesStatus = selectedStatuses.length === 0 || 
                           selectedStatuses.includes(status)
      
      // Use data attribute to mark filtered state (for pagination coordination)
      if (matchesDifficulty && matchesTags && matchesStatus) {
        delete row.dataset.filteredOut
      } else {
        row.dataset.filteredOut = 'true'
      }
    })
    
    this.updateClearButton()
    
    // Dispatch event for pagination to update
    this.element.dispatchEvent(new CustomEvent('filter:changed', { bubbles: true }))
  }
  
  clearAll() {
    this.difficultyCheckboxTargets.forEach(cb => cb.checked = false)
    this.tagCheckboxTargets.forEach(cb => cb.checked = false)
    this.statusCheckboxTargets.forEach(cb => cb.checked = false)
    this.filter()
  }
  
  getSelectedValues(checkboxes) {
    return checkboxes
      .filter(cb => cb.checked)
      .map(cb => cb.value)
  }
  
  updateClearButton() {
    const hasFilters = this.difficultyCheckboxTargets.some(cb => cb.checked) ||
                      this.tagCheckboxTargets.some(cb => cb.checked) ||
                      this.statusCheckboxTargets.some(cb => cb.checked)
    
    if (this.hasClearButtonTarget) {
      this.clearButtonTarget.style.display = hasFilters ? 'block' : 'none'
    }
  }
}
