import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="code-editor"
export default class extends Controller {
  static targets = ["editor", "languageSelect", "fileInput", "hiddenCode"]
  static values = { 
    language: { type: String, default: "python" }
  }
  
  connect() {
    this.initializeEditor()
    this.loadFromLocalStorage()
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
    const lang = event.target.value
    this.languageValue = lang
    
    if (this.editor) {
      const model = this.editor.getModel()
      monaco.editor.setModelLanguage(model, this.getMonacoLanguage(lang))
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
    formData.append('problem_id', this.data.get('problem-id'))
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
    .then(response => {
      if (response.ok) {
        alert('Submission successful!')
        // Clear localStorage after successful submission
        this.clearLocalStorage()
        // Reload to see updated submission status
        window.location.reload()
      } else {
        alert('Submission failed. Please try again.')
      }
    })
    .catch(error => {
      console.error('Error:', error)
      alert('Submission failed. Please try again.')
    })
  }
  
  getMonacoLanguage(lang) {
    const mapping = {
      'python': 'python',
      'python3': 'python',
      'javascript': 'javascript',
      'nodejs': 'javascript',
      'ruby': 'ruby',
      'c': 'c',
      'cpp': 'cpp',
      'cpp11': 'cpp',
      'c++': 'cpp',
      'java': 'java',
      'go': 'go'
    }
    return mapping[lang.toLowerCase()] || 'python'
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
    const problemId = this.data.get('problem-id')
    const code = this.editor.getValue()
    localStorage.setItem(`problem_${problemId}_code`, code)
    localStorage.setItem(`problem_${problemId}_language`, this.languageValue)
  }
  
  loadFromLocalStorage() {
    const problemId = this.data.get('problem-id')
    const savedCode = localStorage.getItem(`problem_${problemId}_code`)
    const savedLanguage = localStorage.getItem(`problem_${problemId}_language`)
    
    if (savedLanguage) {
      this.languageValue = savedLanguage
      if (this.hasLanguageSelectTarget) {
        this.languageSelectTarget.value = savedLanguage
      }
    }
    
    if (savedCode && this.editor) {
      this.editor.setValue(savedCode)
    }
  }
  
  clearLocalStorage() {
    const problemId = this.data.get('problem-id')
    localStorage.removeItem(`problem_${problemId}_code`)
    localStorage.removeItem(`problem_${problemId}_language`)
  }
  
  getCSRFToken() {
    return document.querySelector('meta[name="csrf-token"]').content
  }
}
