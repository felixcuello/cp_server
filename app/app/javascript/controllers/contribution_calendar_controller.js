import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="contribution-calendar"
export default class extends Controller {
  static targets = ["calendar", "tooltip"]
  static values = {
    contributions: Object
  }
  
  connect() {
    this.renderCalendar()
  }
  
  renderCalendar() {
    const calendar = this.calendarTarget
    calendar.innerHTML = '' // Clear existing content
    
    // Create calendar structure
    const today = new Date()
    const oneYearAgo = new Date(today)
    oneYearAgo.setDate(today.getDate() - 364)
    
    // Get all weeks
    const weeks = this.getWeeks(oneYearAgo, today)
    
    // Create month labels
    const monthLabels = this.createMonthLabels(weeks)
    calendar.appendChild(monthLabels)
    
    // Create the grid container
    const grid = document.createElement('div')
    grid.className = 'calendar-grid'
    
    // Create day labels (Mon, Wed, Fri)
    const dayLabels = document.createElement('div')
    dayLabels.className = 'day-labels'
    dayLabels.innerHTML = `
      <div class="day-label"></div>
      <div class="day-label">Mon</div>
      <div class="day-label"></div>
      <div class="day-label">Wed</div>
      <div class="day-label"></div>
      <div class="day-label">Fri</div>
      <div class="day-label"></div>
    `
    grid.appendChild(dayLabels)
    
    // Create weeks
    weeks.forEach(week => {
      const weekColumn = document.createElement('div')
      weekColumn.className = 'week-column'
      
      week.forEach(date => {
        const day = this.createDayCell(date)
        weekColumn.appendChild(day)
      })
      
      grid.appendChild(weekColumn)
    })
    
    calendar.appendChild(grid)
  }
  
  getWeeks(startDate, endDate) {
    const weeks = []
    let currentWeek = []
    const currentDate = new Date(startDate)
    
    // Start from the first Sunday before or on start date
    const dayOfWeek = currentDate.getDay()
    currentDate.setDate(currentDate.getDate() - dayOfWeek)
    
    while (currentDate <= endDate) {
      currentWeek.push(new Date(currentDate))
      
      if (currentDate.getDay() === 6) { // Saturday
        weeks.push(currentWeek)
        currentWeek = []
      }
      
      currentDate.setDate(currentDate.getDate() + 1)
    }
    
    // Add remaining days
    if (currentWeek.length > 0) {
      while (currentWeek.length < 7) {
        currentWeek.push(null) // Fill empty cells
      }
      weeks.push(currentWeek)
    }
    
    return weeks
  }
  
  createMonthLabels(weeks) {
    const container = document.createElement('div')
    container.className = 'month-labels'
    
    let lastMonth = -1
    const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
    
    weeks.forEach((week, index) => {
      const firstDay = week.find(d => d !== null)
      if (firstDay) {
        const month = firstDay.getMonth()
        if (month !== lastMonth && (index === 0 || month !== weeks[index - 1]?.[0]?.getMonth())) {
          const label = document.createElement('div')
          label.className = 'month-label'
          label.textContent = monthNames[month]
          label.style.gridColumn = index + 2 // +2 because of day labels column
          container.appendChild(label)
          lastMonth = month
        }
      }
    })
    
    return container
  }
  
  createDayCell(date) {
    const cell = document.createElement('div')
    cell.className = 'calendar-day'
    
    if (!date) {
      cell.classList.add('empty')
      return cell
    }
    
    const dateString = this.formatDate(date)
    const count = this.contributionsValue[dateString] || 0
    
    // Determine color level (0-4)
    const level = this.getContributionLevel(count)
    cell.classList.add(`level-${level}`)
    
    // Store data for tooltip
    cell.dataset.date = dateString
    cell.dataset.count = count
    
    // Add event listeners
    cell.addEventListener('mouseenter', (e) => this.showTooltip(e))
    cell.addEventListener('mouseleave', () => this.hideTooltip())
    
    return cell
  }
  
  getContributionLevel(count) {
    // Color levels based on submission count
    if (count === 0) return 0
    if (count <= 2) return 1
    if (count <= 5) return 2
    if (count <= 10) return 3
    return 4
  }
  
  formatDate(date) {
    const year = date.getFullYear()
    const month = String(date.getMonth() + 1).padStart(2, '0')
    const day = String(date.getDate()).padStart(2, '0')
    return `${year}-${month}-${day}`
  }
  
  showTooltip(event) {
    const cell = event.target
    const date = cell.dataset.date
    const count = cell.dataset.count
    
    if (!this.hasTooltipTarget) return
    
    const tooltip = this.tooltipTarget
    const formattedDate = new Date(date).toLocaleDateString('en-US', { 
      weekday: 'short', 
      year: 'numeric', 
      month: 'short', 
      day: 'numeric' 
    })
    
    const submissionText = count === '1' ? 'submission' : 'submissions'
    tooltip.innerHTML = `
      <strong>${count} ${submissionText}</strong><br>
      ${formattedDate}
    `
    
    // Show tooltip first to get its dimensions
    tooltip.classList.add('visible')
    
    // Position tooltip relative to the cell
    const cellRect = cell.getBoundingClientRect()
    const tooltipRect = tooltip.getBoundingClientRect()
    
    // Center horizontally above the cell
    let left = cellRect.left + (cellRect.width / 2) - (tooltipRect.width / 2)
    let top = cellRect.top - tooltipRect.height - 8
    
    // Keep tooltip within viewport bounds
    const padding = 10
    if (left < padding) {
      left = padding
    } else if (left + tooltipRect.width > window.innerWidth - padding) {
      left = window.innerWidth - tooltipRect.width - padding
    }
    
    // If tooltip would go above viewport, show below instead
    if (top < padding) {
      top = cellRect.bottom + 8
    }
    
    tooltip.style.left = `${left}px`
    tooltip.style.top = `${top}px`
  }
  
  hideTooltip() {
    if (!this.hasTooltipTarget) return
    this.tooltipTarget.classList.remove('visible')
  }
}
