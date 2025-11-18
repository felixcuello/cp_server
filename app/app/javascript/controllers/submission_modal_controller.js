import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="submission-modal"
export default class extends Controller {
  static targets = ["modal", "title", "message", "icon", "tryAgainBtn", "viewSubmissionsBtn"]
  static values = {
    problemId: Number,
    submissionId: Number
  }
  
  connect() {
    console.log('Submission modal controller connected')
    // Add keyboard listeners when modal is shown
    this.boundHandleKeydown = this.handleKeydown.bind(this)
  }
  
  disconnect() {
    // Clean up event listeners
    document.removeEventListener('keydown', this.boundHandleKeydown)
  }
  
  // Show the modal with success/failure info
  show(data) {
    const { success, status, submissionId } = data
    
    if (success) {
      this.showSuccess(status, submissionId)
    } else {
      this.showError(status)
    }
    
    // Show modal
    this.modalTarget.classList.add('active')
    document.body.style.overflow = 'hidden' // Prevent background scrolling
    
    // Add keyboard listeners
    document.addEventListener('keydown', this.boundHandleKeydown)
    
    // Focus on the modal for keyboard navigation
    this.modalTarget.focus()
  }
  
  showSuccess(status, submissionId) {
    this.submissionIdValue = submissionId
    
    // Set icon and title based on status
    if (status === 'accepted') {
      this.iconTarget.textContent = '✓'
      this.iconTarget.className = 'modal-icon success'
      this.titleTarget.textContent = 'Success!'
      this.messageTarget.textContent = 'Your solution passed all test cases! 🎉'
    } else if (status === 'queued' || status === 'pending' || status === 'running' || status === 'enqueued') {
      this.iconTarget.textContent = '⏳'
      this.iconTarget.className = 'modal-icon queued'
      this.titleTarget.textContent = 'Submission Queued!'
      this.messageTarget.textContent = 'Your code has been submitted successfully and is being evaluated. Check your submissions page for results. 🚀'
    } else {
      this.iconTarget.textContent = '✗'
      this.iconTarget.className = 'modal-icon error'
      this.titleTarget.textContent = 'Submission Complete'
      this.messageTarget.textContent = `Status: ${status.toUpperCase()}`
    }
  }
  
  showError(message) {
    this.iconTarget.textContent = '⚠'
    this.iconTarget.className = 'modal-icon warning'
    this.titleTarget.textContent = 'Submission Failed'
    this.messageTarget.textContent = message || 'Something went wrong. Please try again.'
  }
  
  // Close modal
  close(event) {
    if (event) event.preventDefault()
    
    this.modalTarget.classList.remove('active')
    document.body.style.overflow = '' // Restore scrolling
    document.removeEventListener('keydown', this.boundHandleKeydown)
  }
  
  // Close when clicking outside
  closeOnBackdrop(event) {
    if (event.target === this.modalTarget) {
      this.close()
    }
  }
  
  // Handle keyboard shortcuts
  handleKeydown(event) {
    if (event.key === 'Escape') {
      event.preventDefault()
      this.close()
    } else if (event.key === 'Enter') {
      event.preventDefault()
      this.viewSubmissions()
    }
  }
  
  // Try again - fetch most recent submission and reload with it
  async tryAgain(event) {
    event.preventDefault()
    
    // Get the problem ID from the controller value
    const problemId = this.problemIdValue
    
    if (!problemId) {
      window.location.reload()
      return
    }
    
    try {
      // Fetch the most recent submission for this problem
      const response = await fetch(`/problems/${problemId}/recent_submission`, {
        headers: {
          'Accept': 'application/json'
        }
      })
      
      if (response.ok) {
        const data = await response.json()
        
        if (data.submission_id) {
          window.location.href = `/problems/${problemId}?submission_id=${data.submission_id}`
        } else {
          window.location.href = `/problems/${problemId}`
        }
      } else {
        window.location.href = `/problems/${problemId}`
      }
    } catch (error) {
      console.error('Error fetching recent submission:', error)
      window.location.href = `/problems/${problemId}`
    }
  }
  
  // View submissions
  viewSubmissions(event) {
    if (event) event.preventDefault()
    window.location.href = '/submissions'
  }
}
