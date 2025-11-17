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
  
  // Try again - reload page
  tryAgain(event) {
    event.preventDefault()
    // Just reload the page (clears submission, keeps problem)
    window.location.reload()
  }
  
  // View submissions
  viewSubmissions(event) {
    if (event) event.preventDefault()
    window.location.href = '/submissions'
  }
}
