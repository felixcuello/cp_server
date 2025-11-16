import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="theme"
export default class extends Controller {
  static targets = ["icon"]
  
  connect() {
    // Initialize theme on page load
    this.initializeTheme()
  }
  
  initializeTheme() {
    // Check for saved theme preference or default to system preference
    const savedTheme = localStorage.getItem("theme")
    const systemPrefersDark = window.matchMedia("(prefers-color-scheme: dark)").matches
    
    let theme
    if (savedTheme) {
      theme = savedTheme
    } else if (systemPrefersDark) {
      theme = "dark"
    } else {
      theme = "light"
    }
    
    this.setTheme(theme, false)
    
    // Listen for system theme changes
    window.matchMedia("(prefers-color-scheme: dark)").addEventListener("change", (e) => {
      // Only auto-switch if user hasn't manually set a preference
      if (!localStorage.getItem("theme")) {
        this.setTheme(e.matches ? "dark" : "light", false)
      }
    })
  }
  
  toggle() {
    const currentTheme = document.documentElement.getAttribute("data-theme")
    const newTheme = currentTheme === "dark" ? "light" : "dark"
    this.setTheme(newTheme, true)
  }
  
  setTheme(theme, savePreference = true) {
    // Remove preload class if it exists (prevents transition flash on load)
    document.documentElement.classList.remove("preload")
    
    // Set theme attribute
    document.documentElement.setAttribute("data-theme", theme)
    
    // Update icon if target exists
    if (this.hasIconTarget) {
      this.updateIcon(theme)
    }
    
    // Save preference
    if (savePreference) {
      localStorage.setItem("theme", theme)
    }
  }
  
  updateIcon(theme) {
    if (theme === "dark") {
      this.iconTarget.textContent = "☀️"
      this.iconTarget.setAttribute("title", "Switch to light mode")
    } else {
      this.iconTarget.textContent = "🌙"
      this.iconTarget.setAttribute("title", "Switch to dark mode")
    }
  }
}
