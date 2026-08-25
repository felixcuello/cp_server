import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="sandbox-token-countdown"
// Shows hours and minutes left until the guest sandbox token expires.
export default class extends Controller {
  static targets = ["hours", "minutes"]
  static values = {
    expiresAt: Number
  }

  connect() {
    if (!this.expiresAtValue) {
      return
    }

    this.updateCountdown()
    this.interval = setInterval(() => {
      this.updateCountdown()
    }, 1000)
  }

  disconnect() {
    if (this.interval) {
      clearInterval(this.interval)
    }
  }

  updateCountdown() {
    const diff = this.expiresAtValue - Date.now()

    if (diff <= 0) {
      this.setTime(0, 0)
      if (this.interval) {
        clearInterval(this.interval)
        this.interval = null
      }
      // Reload so an admin extension of expires_at shows a new timer instead of a 404.
      window.location.reload()
      return
    }

    const hours = Math.floor(diff / (1000 * 60 * 60))
    const minutes = Math.floor((diff % (1000 * 60 * 60)) / (1000 * 60))
    this.setTime(hours, minutes)
  }

  setTime(hours, minutes) {
    if (this.hasHoursTarget) {
      this.hoursTarget.textContent = hours.toString().padStart(2, "0")
    }
    if (this.hasMinutesTarget) {
      this.minutesTarget.textContent = minutes.toString().padStart(2, "0")
    }
  }
}
