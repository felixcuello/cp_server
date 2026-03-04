import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["codeEditor", "inputEditor", "languageSelect", "output", "outputContent", "runButton", "runtime", "statusBadge"]
  static values = {
    language: { type: String, default: "python" }
  }

  connect() {
    if (typeof window.monacoLoaded !== 'undefined') {
      window.monacoLoaded.then(() => this.initializeEditors());
    } else {
      this.waitForMonaco();
    }
  }

  waitForMonaco() {
    let attempts = 0;
    const check = () => {
      if (typeof monaco !== 'undefined') {
        this.initializeEditors();
      } else if (attempts < 50) {
        attempts++;
        setTimeout(check, 100);
      }
    };
    check();
  }

  disconnect() {
    if (this.codeEditorInstance) this.codeEditorInstance.dispose();
    if (this.inputEditorInstance) this.inputEditorInstance.dispose();
  }

  initializeEditors() {
    if (typeof monaco === 'undefined') return;

    this.loadFromLocalStorage();

    this.codeEditorInstance = monaco.editor.create(this.codeEditorTarget, {
      value: this.getSavedCode() || this.getDefaultCode(),
      language: this.getMonacoLanguage(this.languageValue),
      theme: this.getTheme(),
      minimap: { enabled: false },
      fontSize: 14,
      lineNumbers: 'on',
      roundedSelection: true,
      scrollBeyondLastLine: false,
      automaticLayout: true,
      tabSize: 4,
      find: {
        addExtraSpaceOnTop: false,
        autoFindInSelection: 'never',
        seedSearchStringFromSelection: 'always'
      }
    });

    this.inputEditorInstance = monaco.editor.create(this.inputEditorTarget, {
      value: this.getSavedInput() || '',
      language: 'plaintext',
      theme: this.getTheme(),
      minimap: { enabled: false },
      fontSize: 14,
      lineNumbers: 'off',
      roundedSelection: true,
      scrollBeyondLastLine: false,
      automaticLayout: true,
      tabSize: 4,
      wordWrap: 'on',
      placeholder: 'Enter input here...'
    });

    this.themeObserver = new MutationObserver(() => {
      const theme = this.getTheme();
      this.codeEditorInstance.updateOptions({ theme });
      this.inputEditorInstance.updateOptions({ theme });
    });
    this.themeObserver.observe(document.documentElement, {
      attributes: true,
      attributeFilter: ['data-theme']
    });

    this.codeEditorInstance.onDidChangeModelContent(() => this.saveToLocalStorage());
    this.inputEditorInstance.onDidChangeModelContent(() => this.saveToLocalStorage());

    // Ctrl/Cmd+Enter to run
    this.codeEditorInstance.addCommand(
      monaco.KeyMod.CtrlCmd | monaco.KeyCode.Enter,
      () => this.run()
    );
    this.inputEditorInstance.addCommand(
      monaco.KeyMod.CtrlCmd | monaco.KeyCode.Enter,
      () => this.run()
    );
  }

  changeLanguage(event) {
    const selectedOption = event.target.options[event.target.selectedIndex];
    const langName = selectedOption.getAttribute('data-lang');
    this.languageValue = langName;

    if (this.codeEditorInstance) {
      const monacoLang = this.getMonacoLanguage(langName);
      monaco.editor.setModelLanguage(this.codeEditorInstance.getModel(), monacoLang);

      const currentCode = this.codeEditorInstance.getValue().trim();
      const defaultCodes = this.getAllDefaultCodes();
      const isDefaultCode = Object.values(defaultCodes).some(t => currentCode === t.trim() || currentCode === '');

      if (isDefaultCode) {
        this.codeEditorInstance.setValue(this.getDefaultCode());
      }
    }

    this.saveToLocalStorage();
  }

  async run() {
    if (!this.codeEditorInstance) return;

    const code = this.codeEditorInstance.getValue();
    if (!code.trim()) {
      this.showOutput('Please write some code before running.', 'error');
      return;
    }

    this.setRunning(true);

    const languageId = this.languageSelectTarget.value;
    const input = this.inputEditorInstance ? this.inputEditorInstance.getValue() : '';

    const formData = new FormData();
    formData.append('programming_language_id', languageId);
    formData.append('input', input);

    const blob = new Blob([code], { type: 'text/plain' });
    formData.append('source_code', blob, 'sandbox.' + this.getFileExtension());

    try {
      const response = await fetch('/sandbox/run', {
        method: 'POST',
        body: formData,
        headers: {
          'X-CSRF-Token': this.getCSRFToken()
        }
      });

      const result = await response.json();

      if (!result.success) {
        this.showOutput(result.error || 'An error occurred', 'error');
        this.showRuntime(null);
        return;
      }

      if (result.status === 'success') {
        this.showOutput(result.output || '(no output)', 'success');
      } else if (result.status === 'compilation_error') {
        this.showOutput(result.error || 'Compilation failed', 'compilation_error');
      } else {
        const errorOutput = result.output ? result.output + '\n\n' + (result.error || '') : (result.error || 'Error');
        this.showOutput(errorOutput.trim(), result.status);
      }

      this.showRuntime(result.runtime_ms);
    } catch (error) {
      this.showOutput('Failed to connect to server: ' + error.message, 'error');
      this.showRuntime(null);
    } finally {
      this.setRunning(false);
    }
  }

  resetCode(event) {
    event.preventDefault();
    const confirmed = confirm('Reset code to default template?\n\nThis will clear your current code and input.');
    if (!confirmed) return;

    if (this.codeEditorInstance) {
      this.codeEditorInstance.setValue(this.getDefaultCode());
    }
    if (this.inputEditorInstance) {
      this.inputEditorInstance.setValue('');
    }
    this.clearLocalStorage();
  }

  openSearch(event) {
    event.preventDefault();
    if (this.codeEditorInstance) {
      this.codeEditorInstance.trigger('keyboard', 'actions.find');
    }
  }

  // --- UI helpers ---

  setRunning(running) {
    if (this.hasRunButtonTarget) {
      this.runButtonTarget.disabled = running;
      if (running) {
        this.runButtonTarget.classList.add('running');
        this.runButtonTarget.querySelector('span:last-child').textContent = 'Running...';
      } else {
        this.runButtonTarget.classList.remove('running');
        this.runButtonTarget.querySelector('span:last-child').textContent = 'RUN';
      }
    }
    if (running) {
      this.showOutput('Running...', 'loading');
      this.showRuntime(null);
    }
  }

  showOutput(text, status) {
    if (!this.hasOutputContentTarget) return;

    const escaped = this.escapeHtml(text);
    this.outputContentTarget.innerHTML = escaped;

    if (this.hasStatusBadgeTarget) {
      const badge = this.statusBadgeTarget;
      badge.className = 'sandbox-status-badge';

      const labels = {
        success: 'OK',
        error: 'Error',
        compilation_error: 'Compilation Error',
        runtime_error: 'Runtime Error',
        time_limit_exceeded: 'Time Limit Exceeded',
        memory_limit_exceeded: 'Memory Limit Exceeded',
        loading: ''
      };

      badge.textContent = labels[status] || status || '';
      if (status && status !== 'loading') {
        badge.classList.add('sandbox-status-' + status.replace(/_/g, '-'));
      }
    }
  }

  showRuntime(ms) {
    if (!this.hasRuntimeTarget) return;
    if (ms !== null && ms !== undefined) {
      this.runtimeTarget.textContent = ms + ' ms';
    } else {
      this.runtimeTarget.textContent = '';
    }
  }

  escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
  }

  // --- Monaco helpers ---

  getMonacoLanguage(lang) {
    const mapping = {
      'python': 'python',
      'python 3': 'python',
      'python3': 'python',
      'javascript': 'javascript',
      'javascript (nodejs)': 'javascript',
      'nodejs': 'javascript',
      'node.js': 'javascript',
      'ruby': 'ruby',
      'c': 'c',
      'cpp': 'cpp',
      'c++': 'cpp',
      'c++11': 'cpp',
      'cpp11': 'cpp',
      'c++ 11': 'cpp',
      'java': 'java',
      'go': 'go',
      'rust': 'rust'
    };
    return mapping[(lang || '').toLowerCase()] || 'plaintext';
  }

  getFileExtension() {
    const mapping = {
      'python': 'py',
      'javascript': 'js',
      'ruby': 'rb',
      'c': 'c',
      'cpp': 'cpp',
      'java': 'java',
      'go': 'go',
      'rust': 'rs'
    };
    return mapping[this.getMonacoLanguage(this.languageValue)] || 'txt';
  }

  getTheme() {
    const isDark = document.documentElement.getAttribute('data-theme') === 'dark';
    return isDark ? 'vs-dark' : 'vs';
  }

  getAllDefaultCodes() {
    return {
      'python': 'import sys\n\nfor line in sys.stdin:\n    print(line.strip())\n',
      'javascript': 'const readline = require("readline");\nconst rl = readline.createInterface({ input: process.stdin });\n\nrl.on("line", (line) => {\n    console.log(line);\n});\n',
      'ruby': 'ARGF.each_line do |line|\n  puts line\nend\n',
      'c': '#include <stdio.h>\n\nint main() {\n    \n    return 0;\n}\n',
      'cpp': '#include <iostream>\nusing namespace std;\n\nint main() {\n    \n    return 0;\n}\n',
      'java': 'public class Main {\n    public static void main(String[] args) {\n        \n    }\n}\n',
      'go': 'package main\n\nimport "fmt"\n\nfunc main() {\n    \n}\n',
      'rust': 'use std::io::{self, BufRead};\n\nfn main() {\n    \n}\n'
    };
  }

  getDefaultCode() {
    const templates = this.getAllDefaultCodes();
    return templates[this.getMonacoLanguage(this.languageValue)] || '// Write your code here\n';
  }

  // --- localStorage ---

  saveToLocalStorage() {
    if (this.codeEditorInstance) {
      localStorage.setItem('sandbox_code', this.codeEditorInstance.getValue());
    }
    if (this.inputEditorInstance) {
      localStorage.setItem('sandbox_input', this.inputEditorInstance.getValue());
    }
    localStorage.setItem('sandbox_language', this.languageValue);
  }

  loadFromLocalStorage() {
    const savedLanguage = localStorage.getItem('sandbox_language');
    if (savedLanguage) {
      this.languageValue = savedLanguage;
      if (this.hasLanguageSelectTarget) {
        const options = Array.from(this.languageSelectTarget.options);
        const match = options.find(opt => opt.getAttribute('data-lang') === savedLanguage.toLowerCase());
        if (match) this.languageSelectTarget.value = match.value;
      }
    }
  }

  getSavedCode() {
    return localStorage.getItem('sandbox_code');
  }

  getSavedInput() {
    return localStorage.getItem('sandbox_input');
  }

  clearLocalStorage() {
    localStorage.removeItem('sandbox_code');
    localStorage.removeItem('sandbox_input');
    localStorage.removeItem('sandbox_language');
  }

  getCSRFToken() {
    return document.querySelector('meta[name="csrf-token"]').content;
  }
}
