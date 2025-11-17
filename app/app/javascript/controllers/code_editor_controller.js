import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="code-editor"
export default class extends Controller {
  static targets = ["editor", "languageSelect", "fileInput", "hiddenCode", "testResults"]
  static values = { 
    language: { type: String, default: "python" },
    problemId: { type: Number }
  }
  
  connect() {
    // Wait for Monaco to be loaded
    if (typeof window.monacoLoaded !== 'undefined') {
      window.monacoLoaded.then(() => {
        this.initializeEditor()
        this.loadFromLocalStorage()
      });
    } else {
      // Fallback: try to initialize directly
      this.waitForMonaco();
    }
  }
  
  waitForMonaco() {
    // Check if Monaco is ready every 100ms, up to 5 seconds
    let attempts = 0;
    const maxAttempts = 50;
    
    const checkMonaco = () => {
      if (typeof monaco !== 'undefined') {
        this.initializeEditor()
        this.loadFromLocalStorage()
      } else if (attempts < maxAttempts) {
        attempts++;
        setTimeout(checkMonaco, 100);
      } else {
        console.error('Monaco Editor failed to load after 5 seconds');
      }
    };
    
    checkMonaco();
  }
  
  disconnect() {
    if (this.editor) {
      this.editor.dispose()
    }
  }
  
  initializeEditor() {
    // Check if Monaco is loaded
    if (typeof monaco === 'undefined') {
      console.error('Monaco Editor not loaded')
      return
    }
    
    // Create the editor
    this.editor = monaco.editor.create(this.editorTarget, {
      value: this.getDefaultCode(),
      language: this.getMonacoLanguage(this.languageValue),
      theme: this.getTheme(),
      minimap: { enabled: false },
      fontSize: 14,
      lineNumbers: 'on',
      roundedSelection: true,
      scrollBeyondLastLine: false,
      automaticLayout: true,
      tabSize: 4
    })
    
    // Listen for theme changes
    this.themeObserver = new MutationObserver(() => {
      this.editor.updateOptions({ theme: this.getTheme() })
    })
    
    this.themeObserver.observe(document.documentElement, {
      attributes: true,
      attributeFilter: ['data-theme']
    })
    
    // Auto-save to localStorage
    this.editor.onDidChangeModelContent(() => {
      this.saveToLocalStorage()
    })
  }
  
  changeLanguage(event) {
    const langId = event.target.value
    
    // Get the selected option's data-lang attribute
    const selectedOption = event.target.options[event.target.selectedIndex]
    const langName = selectedOption.getAttribute('data-lang')
    
    console.log('Language changed to:', langName, 'ID:', langId)
    
    this.languageValue = langName
    
    if (this.editor) {
      const monacoLang = this.getMonacoLanguage(langName)
      console.log('Setting Monaco language to:', monacoLang)
      
      const model = this.editor.getModel()
      monaco.editor.setModelLanguage(model, monacoLang)
      
      // Update the editor's content to the new language template if code is default/empty
      const currentCode = this.editor.getValue().trim()
      const defaultCodes = this.getAllDefaultCodes()
      const isDefaultCode = Object.values(defaultCodes).some(template => 
        currentCode === template.trim() || currentCode === ''
      )
      
      if (isDefaultCode || currentCode === '') {
        console.log('Setting default template for new language')
        this.editor.setValue(this.getDefaultCode())
      }
    }
  }
  
  getAllDefaultCodes() {
    return {
      'python': '# Write your solution here\n\n',
      'javascript': '// Write your solution here\n\n',
      'ruby': '# Write your solution here\n\n',
      'c': '#include <stdio.h>\n\nint main() {\n    // Write your solution here\n    return 0;\n}\n',
      'cpp': '#include <iostream>\nusing namespace std;\n\nint main() {\n    // Write your solution here\n    return 0;\n}\n',
      'java': 'public class Main {\n    public static void main(String[] args) {\n        // Write your solution here\n    }\n}\n',
      'go': 'package main\n\nimport "fmt"\n\nfunc main() {\n    // Write your solution here\n}\n'
    }
  }
  
  async test(event) {
    event.preventDefault()
    
    console.log('Test button clicked!')
    
    const code = this.editor.getValue()
    console.log('Code length:', code.length)
    
    if (!code.trim()) {
      console.log('No code entered')
      this.showTestResults({
        success: false,
        error: 'Please write some code before testing'
      })
      return
    }
    
    // Show loading state
    console.log('Showing loading state...')
    this.showTestResults({
      loading: true
    })
    
    // Get language ID
    const languageId = this.languageSelectTarget.value
    console.log('Language select element:', this.languageSelectTarget)
    console.log('Language ID from select:', languageId)
    
    if (!languageId) {
      console.error('No language selected!')
      this.showTestResults({
        success: false,
        error: 'Please select a programming language'
      })
      return
    }
    
    // Create form data
    const formData = new FormData()
    formData.append('problem_id', this.problemIdValue)
    formData.append('programming_language_id', languageId)
    
    // Create a blob from the code string
    const blob = new Blob([code], { type: 'text/plain' })
    formData.append('source_code', blob, 'solution.' + this.getFileExtension())
    
    console.log('Sending test request to /submissions/test')
    console.log('Problem ID:', this.problemIdValue)
    console.log('Language ID:', languageId)
    
    try {
      const response = await fetch('/submissions/test', {
        method: 'POST',
        body: formData,
        headers: {
          'X-CSRF-Token': this.getCSRFToken()
        }
      })
      
      console.log('Response status:', response.status)
      
      if (!response.ok) {
        const errorText = await response.text()
        console.error('Server error:', errorText)
        throw new Error(`Server returned ${response.status}: ${errorText}`)
      }
      
      const result = await response.json()
      console.log('Test results received:', result)
      this.showTestResults(result)
    } catch (error) {
      console.error('Error running tests:', error)
      this.showTestResults({
        success: false,
        error: `Failed to run tests: ${error.message}`
      })
    }
  }
  
  submit(event) {
    event.preventDefault()
    
    const code = this.editor.getValue()
    if (!code.trim()) {
      alert('Please write some code before submitting')
      return
    }
    
    // Create form data
    const formData = new FormData()
    formData.append('problem_id', this.problemIdValue)
    formData.append('programming_language_id', this.languageSelectTarget.value)
    
    // Create a blob from the code string
    const blob = new Blob([code], { type: 'text/plain' })
    formData.append('source_code', blob, 'solution.' + this.getFileExtension())
    formData.append('authenticity_token', this.getCSRFToken())
    
    // Submit via fetch
    fetch('/submissions/submit', {
      method: 'POST',
      body: formData,
      headers: {
        'X-CSRF-Token': this.getCSRFToken()
      }
    })
    .then(response => response.json())
    .then(data => {
      // Clear localStorage after successful submission
      this.clearLocalStorage()
      
      // Show modal instead of alert
      this.showSubmissionModal({
        success: data.success !== false,
        status: data.status || 'queued',
        submissionId: data.submission_id
      })
    })
    .catch(error => {
      console.error('Error:', error)
      // Show error modal
      this.showSubmissionModal({
        success: false,
        status: 'Submission failed. Please try again.'
      })
    })
  }
  
  showSubmissionModal(data) {
    // Find the submission modal controller
    const modalController = this.application.getControllerForElementAndIdentifier(
      document.querySelector('[data-controller~="submission-modal"]'),
      'submission-modal'
    )
    
    if (modalController) {
      modalController.show(data)
    } else {
      console.error('Submission modal controller not found')
      // Fallback to alert
      if (data.success) {
        alert('Submission successful!')
        window.location.reload()
      } else {
        alert(data.status)
      }
    }
  }
  
  resetCode(event) {
    event.preventDefault()
    
    // Show confirmation dialog
    const confirmed = confirm(
      '⚠️ Are you sure you want to reset the code?\n\n' +
      'This will:\n' +
      '• Delete your current code\n' +
      '• Load the default template\n' +
      '• Clear saved code from browser storage\n\n' +
      'This action cannot be undone!'
    )
    
    if (!confirmed) {
      console.log('Code reset cancelled by user')
      return
    }
    
    console.log('Resetting code to default template')
    
    // Clear localStorage
    this.clearLocalStorage()
    
    // Reset editor to default template
    if (this.editor) {
      this.editor.setValue(this.getDefaultCode())
      console.log('Code reset to default template')
    }
  }
  
  showTestResults(result) {
    console.log('showTestResults called with:', result)
    
    if (!this.hasTestResultsTarget) {
      console.error('Test results target not found!')
      return
    }
    
    const container = this.testResultsTarget
    
    if (result.loading) {
      container.innerHTML = `
        <div class="test-results-loading">
          <div class="spinner">⏱</div>
          <div>Running test cases...</div>
        </div>
      `
      container.style.display = 'block'
      return
    }
    
    if (!result.success) {
      container.innerHTML = `
        <div class="test-results-error">
          <div class="error-icon">✗</div>
          <div class="error-message">${result.error || 'An error occurred'}</div>
        </div>
      `
      container.style.display = 'block'
      return
    }
    
    // Build results HTML
    let html = `
      <div class="test-results-header ${result.overall_status}">
        <span class="status-icon">${result.overall_status === 'passed' ? '✓' : '✗'}</span>
        <span class="status-text">${result.overall_status === 'passed' ? 'All tests passed!' : 'Some tests failed'}</span>
      </div>
      <div class="test-cases-list">
    `
    
    result.test_results.forEach(test => {
      const statusClass = test.status === 'passed' ? 'passed' : 'failed'
      const statusIcon = test.status === 'passed' ? '✓' : '✗'
      
      html += `
        <div class="test-case ${statusClass}">
          <div class="test-case-header">
            <span class="test-icon">${statusIcon}</span>
            <span class="test-title">Example ${test.example_number}</span>
            ${test.runtime ? `<span class="test-runtime">${test.runtime} ms</span>` : ''}
          </div>
          <div class="test-case-body">
            <div class="test-section">
              <div class="test-label">Input:</div>
              <pre class="test-value">${this.escapeHtml(test.input)}</pre>
            </div>
            <div class="test-section">
              <div class="test-label">Expected:</div>
              <pre class="test-value">${this.escapeHtml(test.expected_output)}</pre>
            </div>
            <div class="test-section">
              <div class="test-label">Your Output:</div>
              <pre class="test-value ${test.status === 'passed' ? 'correct' : 'incorrect'}">${this.escapeHtml(test.actual_output || '(no output)')}</pre>
            </div>
            ${test.error_message ? `
              <div class="test-error">
                <strong>Error:</strong> ${test.error_message}
              </div>
            ` : ''}
          </div>
        </div>
      `
    })
    
    html += `</div>`
    
    container.innerHTML = html
    container.style.display = 'block'
    
    // Scroll to results
    container.scrollIntoView({ behavior: 'smooth', block: 'nearest' })
  }
  
  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }
  
  getMonacoLanguage(lang) {
    const mapping = {
      'python': 'python',
      'python3': 'python',
      'javascript': 'javascript',
      'nodejs': 'javascript',
      'node.js': 'javascript',
      'ruby': 'ruby',
      'c': 'c',
      'cpp': 'cpp',
      'c++': 'cpp',
      'cpp11': 'cpp',
      'c++ 11': 'cpp',
      'java': 'java',
      'go': 'go'
    }
    return mapping[lang.toLowerCase()] || 'plaintext'
  }
  
  getFileExtension() {
    const mapping = {
      'python': 'py',
      'javascript': 'js',
      'ruby': 'rb',
      'c': 'c',
      'cpp': 'cpp',
      'java': 'java',
      'go': 'go'
    }
    return mapping[this.getMonacoLanguage(this.languageValue)] || 'txt'
  }
  
  getTheme() {
    const isDark = document.documentElement.getAttribute('data-theme') === 'dark'
    return isDark ? 'vs-dark' : 'vs'
  }
  
  getDefaultCode() {
    const templates = {
      'python': '# Write your solution here\n\n',
      'javascript': '// Write your solution here\n\n',
      'ruby': '# Write your solution here\n\n',
      'c': '#include <stdio.h>\n\nint main() {\n    // Write your solution here\n    return 0;\n}\n',
      'cpp': '#include <iostream>\nusing namespace std;\n\nint main() {\n    // Write your solution here\n    return 0;\n}\n',
      'java': 'public class Main {\n    public static void main(String[] args) {\n        // Write your solution here\n    }\n}\n',
      'go': 'package main\n\nimport "fmt"\n\nfunc main() {\n    // Write your solution here\n}\n'
    }
    return templates[this.getMonacoLanguage(this.languageValue)] || '// Write your solution here\n'
  }
  
  saveToLocalStorage() {
    const problemId = this.problemIdValue
    const code = this.editor.getValue()
    localStorage.setItem(`problem_${problemId}_code`, code)
    localStorage.setItem(`problem_${problemId}_language`, this.languageValue)
  }
  
  loadFromLocalStorage() {
    const problemId = this.problemIdValue
    const savedCode = localStorage.getItem(`problem_${problemId}_code`)
    const savedLanguage = localStorage.getItem(`problem_${problemId}_language`)
    
    if (savedLanguage) {
      this.languageValue = savedLanguage
      if (this.hasLanguageSelectTarget) {
        // Find the option with matching data-lang attribute
        const options = Array.from(this.languageSelectTarget.options)
        const matchingOption = options.find(opt => 
          opt.getAttribute('data-lang') === savedLanguage.toLowerCase()
        )
        if (matchingOption) {
          this.languageSelectTarget.value = matchingOption.value
          console.log('Restored language from localStorage:', savedLanguage)
        }
      }
    }
    
    if (savedCode && this.editor) {
      this.editor.setValue(savedCode)
      console.log('Restored code from localStorage')
    }
  }
  
  clearLocalStorage() {
    const problemId = this.problemIdValue
    localStorage.removeItem(`problem_${problemId}_code`)
    localStorage.removeItem(`problem_${problemId}_language`)
  }
  
  getCSRFToken() {
    return document.querySelector('meta[name="csrf-token"]').content
  }
}
