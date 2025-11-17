import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="difficulty-chart"
export default class extends Controller {
  static targets = ["canvas"]
  static values = {
    easy: Number,
    medium: Number,
    hard: Number
  }
  
  connect() {
    // Wait for Chart.js to be loaded
    if (typeof Chart !== 'undefined') {
      this.renderChart()
    } else {
      // Retry after a short delay
      setTimeout(() => this.renderChart(), 100)
    }
  }
  
  disconnect() {
    if (this.chart) {
      this.chart.destroy()
    }
  }
  
  renderChart() {
    if (typeof Chart === 'undefined') {
      console.error('Chart.js not loaded')
      return
    }
    
    const total = this.easyValue + this.mediumValue + this.hardValue
    
    // If no data, show empty state
    if (total === 0) {
      this.canvasTarget.parentElement.innerHTML = '<p class="chart-empty-state">No problems solved yet</p>'
      return
    }
    
    const ctx = this.canvasTarget.getContext('2d')
    
    // Get theme colors
    const isDark = document.documentElement.getAttribute('data-theme') === 'dark'
    const textColor = isDark ? '#e0e0e0' : '#333333'
    
    this.chart = new Chart(ctx, {
      type: 'doughnut',
      data: {
        labels: ['Easy', 'Medium', 'Hard'],
        datasets: [{
          data: [this.easyValue, this.mediumValue, this.hardValue],
          backgroundColor: [
            '#4CAF50',  // Easy - Green
            '#FFA500',  // Medium - Orange
            '#F44336'   // Hard - Red
          ],
          borderColor: isDark ? '#1e1e1e' : '#ffffff',
          borderWidth: 3,
          hoverOffset: 10
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: true,
        plugins: {
          legend: {
            position: 'bottom',
            labels: {
              color: textColor,
              font: {
                size: 13,
                family: 'Arial, sans-serif',
                weight: '600'
              },
              padding: 15,
              usePointStyle: true,
              pointStyle: 'circle'
            }
          },
          tooltip: {
            backgroundColor: isDark ? '#2d2d2d' : '#ffffff',
            titleColor: textColor,
            bodyColor: textColor,
            borderColor: isDark ? '#444444' : '#e0e0e0',
            borderWidth: 1,
            padding: 12,
            displayColors: true,
            callbacks: {
              label: (context) => {
                const label = context.label || ''
                const value = context.parsed
                const percentage = ((value / total) * 100).toFixed(1)
                return ` ${label}: ${value} (${percentage}%)`
              }
            }
          },
          datalabels: {
            color: '#ffffff',
            font: {
              size: 14,
              weight: 'bold',
              family: 'Arial, sans-serif'
            },
            formatter: (value, context) => {
              if (value === 0) return '' // Don't show label for 0
              const percentage = ((value / total) * 100).toFixed(1)
              return `${percentage}%`
            },
            anchor: 'center',
            align: 'center',
            offset: 0
          }
        },
        cutout: '60%',  // Makes it a donut chart
        animation: {
          animateRotate: true,
          animateScale: true,
          duration: 1000,
          easing: 'easeOutQuart'
        }
      },
      plugins: [ChartDataLabels]
    })
    
    // Update chart when theme changes
    const observer = new MutationObserver(() => {
      this.updateChartTheme()
    })
    
    observer.observe(document.documentElement, {
      attributes: true,
      attributeFilter: ['data-theme']
    })
    
    // Store observer for cleanup
    this.themeObserver = observer
  }
  
  updateChartTheme() {
    if (!this.chart) return
    
    const isDark = document.documentElement.getAttribute('data-theme') === 'dark'
    const textColor = isDark ? '#e0e0e0' : '#333333'
    const borderColor = isDark ? '#1e1e1e' : '#ffffff'
    const tooltipBg = isDark ? '#2d2d2d' : '#ffffff'
    const tooltipBorder = isDark ? '#444444' : '#e0e0e0'
    
    // Update colors
    this.chart.options.plugins.legend.labels.color = textColor
    this.chart.data.datasets[0].borderColor = borderColor
    this.chart.options.plugins.tooltip.backgroundColor = tooltipBg
    this.chart.options.plugins.tooltip.titleColor = textColor
    this.chart.options.plugins.tooltip.bodyColor = textColor
    this.chart.options.plugins.tooltip.borderColor = tooltipBorder
    
    this.chart.update()
  }
  
  disconnect() {
    if (this.chart) {
      this.chart.destroy()
    }
    if (this.themeObserver) {
      this.themeObserver.disconnect()
    }
  }
}
