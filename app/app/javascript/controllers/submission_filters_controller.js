import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="submission-filters"
export default class extends Controller {
  static targets = ["panel"]
  
  toggle() {
    if (this.panelTarget.style.display === "none") {
      this.panelTarget.style.display = "block"
    } else {
      this.panelTarget.style.display = "none"
    }
  }
}
