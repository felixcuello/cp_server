import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="contest-countdown"
// Displays countdown timer for contest start/end times
export default class extends Controller {
  static targets = ["days", "hours", "minutes", "seconds"]
  static values = {
    startTime: Number,
    endTime: Number
  }

  connect() {
    // Determine which time to countdown to
    this.targetTime = this.startTimeValue || this.endTimeValue
    this.isStartCountdown = !!this.startTimeValue

    if (!this.targetTime) {
      console.error("Contest countdown: No start or end time provided")
      return
    }

    // Update immediately
    this.updateCountdown()

    // Update every second
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
    const now = Date.now()
    const diff = this.targetTime - now

    if (diff <= 0) {
      // Countdown reached zero
      this.setTime(0, 0, 0, 0)

      if (this.isStartCountdown) {
        // Reload page with random delay (200-1500ms)
        const delay = Math.random() * 1300 + 200
        setTimeout(() => {
          window.location.reload()
        }, delay)
      }
      
      // Stop the interval
      if (this.interval) {
        clearInterval(this.interval)
        this.interval = null
      }
      return
    }

    // Calculate time components
    const days = Math.floor(diff / (1000 * 60 * 60 * 24))
    const hours = Math.floor((diff % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60))
    const minutes = Math.floor((diff % (1000 * 60 * 60)) / (1000 * 60))
    const seconds = Math.floor((diff % (1000 * 60)) / 1000)

    this.setTime(days, hours, minutes, seconds)
  }

  setTime(days, hours, minutes, seconds) {
    if (this.hasDaysTarget) {
      this.daysTarget.textContent = days.toString().padStart(2, '0')
    }
    if (this.hasHoursTarget) {
      this.hoursTarget.textContent = hours.toString().padStart(2, '0')
    }
    if (this.hasMinutesTarget) {
      this.minutesTarget.textContent = minutes.toString().padStart(2, '0')
    }
    if (this.hasSecondsTarget) {
      this.secondsTarget.textContent = seconds.toString().padStart(2, '0')
    }
  }
}
