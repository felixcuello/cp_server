import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "codeEditor", "inputEditor", "languageSelect", "output", "outputContent",
    "runButton", "runtime", "statusBadge",
    "manButton", "runPane", "docsPane", "manSearch", "manNav", "manFallback",
    "manTitle", "manBody"
  ]
  static values = {
    language: { type: String, default: "python" },
    token: { type: String, default: "" },
    locale: { type: String, default: "en" },
    missingLabel: { type: String, default: "Missing" }
  }

  connect() {
    this.docsOpen = false
    this.manIndexData = null
    this.boundManKeydown = this.onManKeydown.bind(this)
    this.boundManBodyClick = this.onManBodyClick.bind(this)
    document.addEventListener("keydown", this.boundManKeydown)

    if (this.hasManBodyTarget) {
      this.manBodyTarget.addEventListener("click", this.boundManBodyClick)
    }

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
    document.removeEventListener("keydown", this.boundManKeydown)
    if (this.hasManBodyTarget) {
      this.manBodyTarget.removeEventListener("click", this.boundManBodyClick)
    }
    if (this.codeEditorInstance) this.codeEditorInstance.dispose();
    if (this.inputEditorInstance) this.inputEditorInstance.dispose();
  }

  initializeEditors() {
    if (typeof monaco === 'undefined') return;

    this.loadFromLocalStorage();

    if (this.hasLanguageSelectTarget) {
      const selected = this.languageSelectTarget.selectedOptions[0];
      const langName = selected && selected.getAttribute("data-lang");
      if (langName) this.languageValue = langName;
    }

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

    this.syncManButton();
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
    this.syncManButton();
    if (!this.manAvailable() && this.docsOpen) {
      this.closeMan();
    }
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
      const response = await fetch(this.runUrl(), {
        method: 'POST',
        body: formData,
        headers: {
          'X-CSRF-Token': this.getCSRFToken()
        }
      });

      if (response.status === 404) {
        window.location.assign(window.location.pathname);
        return;
      }

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

  manAvailable() {
    const monacoLang = this.getMonacoLanguage(this.languageValue);
    return monacoLang === "c" || monacoLang === "cpp";
  }

  syncManButton() {
    if (!this.hasManButtonTarget) return;
    this.manButtonTarget.hidden = !this.manAvailable();
  }

  toggleMan(event) {
    if (event) event.preventDefault();
    if (!this.manAvailable()) return;
    if (this.docsOpen) {
      this.closeMan();
    } else {
      this.openMan();
    }
  }

  async openMan() {
    if (!this.hasDocsPaneTarget || !this.hasRunPaneTarget) return;

    this.docsOpen = true;
    this.runPaneTarget.hidden = true;
    this.docsPaneTarget.hidden = false;
    if (this.hasManSearchTarget) this.manSearchTarget.focus();

    await this.ensureManIndex();
    this.renderManNav();
  }

  closeMan() {
    if (!this.hasDocsPaneTarget || !this.hasRunPaneTarget) return;

    this.docsOpen = false;
    this.docsPaneTarget.hidden = true;
    this.runPaneTarget.hidden = false;
    if (this.inputEditorInstance) {
      this.inputEditorInstance.layout();
    }
  }

  onManKeydown(event) {
    if (event.key === "Escape" && this.docsOpen) {
      event.preventDefault();
      this.closeMan();
      return;
    }

    if ((event.ctrlKey || event.metaKey) && event.shiftKey && (event.key === "M" || event.key === "m")) {
      if (!this.manAvailable()) return;
      event.preventDefault();
      this.toggleMan();
    }
  }

  async ensureManIndex() {
    if (this.manIndexData) return;

    try {
      const response = await fetch(this.manIndexUrl(), {
        headers: { "Accept": "application/json" }
      });
      if (response.status === 404) {
        window.location.assign(window.location.pathname);
        return;
      }
      if (!response.ok) {
        this.manIndexData = { pages: [], topics: [] };
        return;
      }
      this.manIndexData = await response.json();
    } catch (_error) {
      this.manIndexData = { pages: [], topics: [] };
    }
  }

  filterManPages() {
    this.renderManNav();
  }

  renderManNav() {
    if (!this.hasManNavTarget || !this.manIndexData) return;

    const query = this.hasManSearchTarget ? this.manSearchTarget.value.trim().toLowerCase() : "";
    if (query) {
      this.renderManSearchResults(query);
    } else {
      this.renderManTopics();
    }
  }

  renderManTopics() {
    const topics = this.manIndexData.topics || [];
    const html = topics.map((topic) => {
      const pages = (topic.pages || []).map((page) => this.manNavPageHtml(page)).join("");
      return `<div class="sandbox-docs-topic">
        <div class="sandbox-docs-topic-label">${this.escapeHtml(topic.label || topic.key || "")}</div>
        ${pages}
      </div>`;
    }).join("");
    this.manNavTarget.innerHTML = html || `<div class="sandbox-docs-empty">${this.escapeHtml(this.missingLabelValue)}</div>`;
    this.bindManNavClicks();
  }

  renderManSearchResults(query) {
    const pages = (this.manIndexData.pages || []).filter((page) => {
      const name = (page.name || "").toLowerCase();
      const title = (page.title || "").toLowerCase();
      const section = (page.section || "").toLowerCase();
      return name.includes(query) || title.includes(query) || `${name}(${section})`.includes(query);
    }).slice(0, 80);

    if (!pages.length) {
      this.manNavTarget.innerHTML = `<div class="sandbox-docs-empty">${this.escapeHtml(this.missingLabelValue)}</div>`;
      return;
    }

    this.manNavTarget.innerHTML = pages.map((page) => this.manNavPageHtml(page)).join("");
    this.bindManNavClicks();
  }

  manNavPageHtml(page) {
    const missing = page.missing === true;
    const label = page.section ? `${page.name}(${page.section})` : page.name;
    const extra = missing ? ` <span class="sandbox-docs-missing-tag">${this.escapeHtml(this.missingLabelValue)}</span>` : "";
    const active = this.currentManKey === `${page.name}:${page.section || ""}` ? " is-active" : "";
    const missingClass = missing ? " is-missing" : "";
    return `<button type="button" class="sandbox-docs-topic-page${active}${missingClass}"
              data-man-name="${this.escapeHtml(page.name || "")}"
              data-man-section="${this.escapeHtml(page.section || "")}"
              data-man-missing="${missing ? "true" : "false"}">${this.escapeHtml(label)}${extra}</button>`;
  }

  bindManNavClicks() {
    this.manNavTarget.querySelectorAll("[data-man-name]").forEach((button) => {
      button.addEventListener("click", () => {
        if (button.dataset.manMissing === "true") {
          this.showManMissing(button.dataset.manName, button.dataset.manSection);
          return;
        }
        this.openManPage(button.dataset.manSection, button.dataset.manName);
      });
    });
  }

  onManBodyClick(event) {
    const link = event.target.closest("[data-man-name]");
    if (!link || !this.manBodyTarget.contains(link)) return;
    event.preventDefault();
    const section = link.dataset.manSection;
    const name = link.dataset.manName;
    if (!section || !name) {
      this.showManMissing(name, section);
      return;
    }
    this.openManPage(section, name);
  }

  showManMissing(name, section) {
    this.currentManKey = `${name || ""}:${section || ""}`;
    if (this.hasManFallbackTarget) this.manFallbackTarget.hidden = true;
    if (this.hasManTitleTarget) {
      const suffix = section ? `(${section})` : "";
      this.manTitleTarget.textContent = `${name || ""}${suffix}`;
    }
    if (this.hasManBodyTarget) {
      this.manBodyTarget.innerHTML = `<p class="sandbox-docs-missing">${this.escapeHtml(this.missingLabelValue)}</p>`;
    }
    this.renderManNav();
  }

  async openManPage(section, name) {
    this.currentManKey = `${name}:${section}`;
    try {
      const response = await fetch(this.manPageUrl(section, name), {
        headers: { "Accept": "application/json" }
      });
      if (response.status === 404) {
        window.location.assign(window.location.pathname);
        return;
      }
      if (response.status === 422) {
        this.showManMissing(name, section);
        return;
      }
      const result = await response.json();
      if (result.missing) {
        this.showManMissing(result.name || name, result.section || section);
        return;
      }
      if (this.hasManFallbackTarget) {
        this.manFallbackTarget.hidden = !result.fallback;
      }
      if (this.hasManTitleTarget) {
        this.manTitleTarget.textContent = `${result.name}(${result.section})`;
      }
      if (this.hasManBodyTarget) {
        this.manBodyTarget.innerHTML = result.html || `<p class="sandbox-docs-missing">${this.escapeHtml(this.missingLabelValue)}</p>`;
      }
      this.renderManNav();
    } catch (_error) {
      this.showManMissing(name, section);
    }
  }

  manIndexUrl() {
    const locale = "?locale=" + encodeURIComponent(this.localeValue);
    if (this.tokenValue) {
      return "/sandbox/" + encodeURIComponent(this.tokenValue) + "/man/index" + locale;
    }
    return "/sandbox/man/index" + locale;
  }

  manPageUrl(section, name) {
    const prefix = this.tokenValue
      ? "/sandbox/" + encodeURIComponent(this.tokenValue) + "/man/"
      : "/sandbox/man/";
    return prefix + encodeURIComponent(section) + "/" + encodeURIComponent(name) +
      "?locale=" + encodeURIComponent(this.localeValue);
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
      'c89': 'c',
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

  // Logged-in sandbox posts to /sandbox/run. Guest capability URLs must keep the token in the path.
  runUrl() {
    if (this.tokenValue) {
      return '/sandbox/' + encodeURIComponent(this.tokenValue) + '/run';
    }
    return '/sandbox/run';
  }
}
