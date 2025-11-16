import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="submission-status"
// Polls for submission status updates (for running/queued submissions)
export default class extends Controller {
  static values = {
    id: Number,
    current: String
  }
  
  connect() {
    // Only poll if submission is in progress
    if (this.shouldPoll()) {
      this.startPolling()
    }
  }
  
  disconnect() {
    this.stopPolling()
  }
  
  shouldPoll() {
    const status = this.currentValue.toLowerCase()
    return status === 'running' || 
           status === 'queued' || 
           status === 'enqueued' ||
           status === 'compiling'
  }
  
  startPolling() {
    // Poll every 2 seconds
    this.pollInterval = setInterval(() => {
      this.checkStatus()
    }, 2000)
  }
  
  stopPolling() {
    if (this.pollInterval) {
      clearInterval(this.pollInterval)
    }
  }
  
  async checkStatus() {
    try {
      const response = await fetch(`/submissions/${this.idValue}.json`)
      const data = await response.json()
      
      if (data.status !== this.currentValue) {
        // Status changed, reload the page
        window.location.reload()
      }
      
      // Stop polling if submission is no longer in progress
      if (!this.shouldPollWithStatus(data.status)) {
        this.stopPolling()
      }
    } catch (error) {
      console.error('Error checking submission status:', error)
    }
  }
  
  shouldPollWithStatus(status) {
    const normalizedStatus = status.toLowerCase()
    return normalizedStatus === 'running' || 
           normalizedStatus === 'queued' || 
           normalizedStatus === 'enqueued' ||
           normalizedStatus === 'compiling'
  }
}
