import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="drawer"
export default class extends Controller {
  static targets = ["drawer", "overlay"]
  
  connect() {
    // Close drawer on escape key
    this.escapeHandler = this.handleEscape.bind(this)
    document.addEventListener("keydown", this.escapeHandler)
  }
  
  disconnect() {
    document.removeEventListener("keydown", this.escapeHandler)
  }
  
  toggle() {
    if (this.drawerTarget.classList.contains("drawer-open")) {
      this.close()
    } else {
      this.open()
    }
  }
  
  open() {
    this.drawerTarget.classList.add("drawer-open")
    this.overlayTarget.classList.add("overlay-visible")
    // Prevent body scroll when drawer is open
    document.body.style.overflow = "hidden"
  }
  
  close() {
    this.drawerTarget.classList.remove("drawer-open")
    this.overlayTarget.classList.remove("overlay-visible")
    // Restore body scroll
    document.body.style.overflow = ""
  }
  
  handleEscape(event) {
    if (event.key === "Escape") {
      this.close()
    }
  }
  
  // Close when clicking overlay
  closeOnOverlay(event) {
    if (event.target === this.overlayTarget) {
      this.close()
    }
  }
}
