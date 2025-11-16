import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="copy-button"
export default class extends Controller {
  static targets = ["source"]
  
  copy(event) {
    event.preventDefault()
    
    const text = this.sourceTarget.textContent || this.sourceTarget.innerText
    
    navigator.clipboard.writeText(text).then(() => {
      // Show success feedback
      const button = event.currentTarget
      const originalText = button.textContent
      button.textContent = '✓ Copied!'
      button.classList.add('copied')
      
      setTimeout(() => {
        button.textContent = originalText
        button.classList.remove('copied')
      }, 2000)
    }).catch(err => {
      console.error('Failed to copy:', err)
      alert('Failed to copy to clipboard')
    })
  }
}
