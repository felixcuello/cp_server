import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="problem-tabs"
export default class extends Controller {
  static targets = ["tab", "panel"]
  
  switch(event) {
    const targetTab = event.currentTarget.dataset.tab
    
    // Update active tab
    this.tabTargets.forEach(tab => {
      if (tab.dataset.tab === targetTab) {
        tab.classList.add('active')
      } else {
        tab.classList.remove('active')
      }
    })
    
    // Update visible panel
    this.panelTargets.forEach(panel => {
      if (panel.dataset.panel === targetTab) {
        panel.classList.add('active')
      } else {
        panel.classList.remove('active')
      }
    })
  }
}
