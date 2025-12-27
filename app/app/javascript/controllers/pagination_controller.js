import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="pagination"
export default class extends Controller {
  static targets = ["row", "info", "prevButton", "nextButton", "pageNumbers"]
  static values = { 
    perPage: { type: Number, default: 20 },
    currentPage: { type: Number, default: 1 }
  }
  
  connect() {
    // Listen for filter/search changes
    this.element.addEventListener("filter:changed", () => this.resetAndPaginate())
    this.element.addEventListener("search:changed", () => this.resetAndPaginate())
    
    // Initial pagination
    this.paginate()
  }
  
  resetAndPaginate() {
    this.currentPageValue = 1
    this.paginate()
  }
  
  paginate() {
    const allRows = this.rowTargets
    // Get rows that aren't hidden by filters/search (check data attribute, not display)
    const visibleRows = allRows.filter(row => !row.dataset.filteredOut && !row.dataset.searchedOut)
    
    const totalItems = visibleRows.length
    const totalPages = Math.max(1, Math.ceil(totalItems / this.perPageValue))
    
    // Ensure current page is valid
    if (this.currentPageValue > totalPages) {
      this.currentPageValue = totalPages
    }
    if (this.currentPageValue < 1) {
      this.currentPageValue = 1
    }
    
    const startIndex = (this.currentPageValue - 1) * this.perPageValue
    const endIndex = startIndex + this.perPageValue
    
    // Hide all rows first
    allRows.forEach(row => {
      row.style.display = 'none'
    })
    
    // Show only the rows for current page (that aren't filtered/searched out)
    visibleRows.forEach((row, index) => {
      if (index >= startIndex && index < endIndex) {
        row.style.display = ''
      }
    })
    
    // Update pagination info
    this.updateInfo(startIndex, endIndex, totalItems)
    this.updateButtons(totalPages)
    this.updatePageNumbers(totalPages)
  }
  
  updateInfo(startIndex, endIndex, totalItems) {
    if (this.hasInfoTarget) {
      if (totalItems === 0) {
        this.infoTarget.textContent = ''
      } else {
        const start = startIndex + 1
        const end = Math.min(endIndex, totalItems)
        this.infoTarget.textContent = `${start}-${end} of ${totalItems}`
      }
    }
  }
  
  updateButtons(totalPages) {
    if (this.hasPrevButtonTarget) {
      this.prevButtonTarget.disabled = this.currentPageValue <= 1
    }
    if (this.hasNextButtonTarget) {
      this.nextButtonTarget.disabled = this.currentPageValue >= totalPages
    }
  }
  
  updatePageNumbers(totalPages) {
    if (!this.hasPageNumbersTarget) return
    
    this.pageNumbersTarget.innerHTML = ''
    
    if (totalPages <= 1) return
    
    const currentPage = this.currentPageValue
    const pages = this.getPageRange(currentPage, totalPages)
    
    pages.forEach((page, index) => {
      if (page === '...') {
        const ellipsis = document.createElement('span')
        ellipsis.className = 'pagination-ellipsis'
        ellipsis.textContent = '...'
        this.pageNumbersTarget.appendChild(ellipsis)
      } else {
        const button = document.createElement('button')
        button.className = `pagination-page ${page === currentPage ? 'active' : ''}`
        button.textContent = page
        button.addEventListener('click', () => this.goToPage(page))
        this.pageNumbersTarget.appendChild(button)
      }
    })
  }
  
  getPageRange(currentPage, totalPages) {
    // Show first, last, current, and neighbors with ellipsis
    const pages = []
    const delta = 2 // Number of pages to show around current
    
    if (totalPages <= 7) {
      // Show all pages if 7 or fewer
      for (let i = 1; i <= totalPages; i++) {
        pages.push(i)
      }
    } else {
      // Always show first page
      pages.push(1)
      
      // Calculate range around current page
      let rangeStart = Math.max(2, currentPage - delta)
      let rangeEnd = Math.min(totalPages - 1, currentPage + delta)
      
      // Adjust if at edges
      if (currentPage <= delta + 1) {
        rangeEnd = Math.min(totalPages - 1, delta * 2 + 2)
      } else if (currentPage >= totalPages - delta) {
        rangeStart = Math.max(2, totalPages - delta * 2 - 1)
      }
      
      // Add ellipsis before range if needed
      if (rangeStart > 2) {
        pages.push('...')
      }
      
      // Add range
      for (let i = rangeStart; i <= rangeEnd; i++) {
        pages.push(i)
      }
      
      // Add ellipsis after range if needed
      if (rangeEnd < totalPages - 1) {
        pages.push('...')
      }
      
      // Always show last page
      pages.push(totalPages)
    }
    
    return pages
  }
  
  prev() {
    if (this.currentPageValue > 1) {
      this.currentPageValue--
      this.paginate()
    }
  }
  
  next() {
    const visibleRows = this.rowTargets.filter(row => !row.dataset.filteredOut && !row.dataset.searchedOut)
    const totalPages = Math.ceil(visibleRows.length / this.perPageValue)
    
    if (this.currentPageValue < totalPages) {
      this.currentPageValue++
      this.paginate()
    }
  }
  
  goToPage(page) {
    this.currentPageValue = page
    this.paginate()
  }
}
