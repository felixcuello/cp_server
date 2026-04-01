# frozen_string_literal: true

module ApplicationHelper
  # Generate a simple git-diff-like output between expected and actual
  # Returns HTML with red lines for missing (expected) and green for extra (actual)
  # When show_whitespace is true, displays spaces and tabs visibly
  def simple_diff(expected, actual, show_whitespace: true)
    return '' if expected.blank? && actual.blank?

    expected_lines = (expected || '').split("\n", -1)
    actual_lines = (actual || '').split("\n", -1)

    # Track if there's a trailing newline difference
    expected_has_trailing_newline = expected&.end_with?("\n")
    actual_has_trailing_newline = actual&.end_with?("\n")

    # Remove trailing empty line if it exists (artifact of split)
    expected_lines.pop if expected_lines.last == '' && expected_has_trailing_newline
    actual_lines.pop if actual_lines.last == '' && actual_has_trailing_newline

    result = []
    result << '<div class="diff-output">'
    result << '<pre class="diff-content">'

    # Use LCS to find common lines
    lcs = longest_common_subsequence(expected_lines, actual_lines)

    exp_idx = 0
    act_idx = 0
    lcs_idx = 0

    while exp_idx < expected_lines.length || act_idx < actual_lines.length
      if lcs_idx < lcs.length &&
         exp_idx < expected_lines.length && expected_lines[exp_idx] == lcs[lcs_idx] &&
         act_idx < actual_lines.length && actual_lines[act_idx] == lcs[lcs_idx]
        # Common line
        line_content = show_whitespace ? format_whitespace(expected_lines[exp_idx]) : h(expected_lines[exp_idx])
        result << %(<span class="diff-context"> #{line_content}<span class="diff-newline">↵</span></span>\n)
        exp_idx += 1
        act_idx += 1
        lcs_idx += 1
      elsif exp_idx < expected_lines.length && (lcs_idx >= lcs.length || expected_lines[exp_idx] != lcs[lcs_idx])
        # Line only in expected (missing from actual) - show in red
        line_content = show_whitespace ? format_whitespace(expected_lines[exp_idx], :removed) : h(expected_lines[exp_idx])
        result << %(<span class="diff-removed">-#{line_content}<span class="diff-newline">↵</span></span>\n)
        exp_idx += 1
      elsif act_idx < actual_lines.length && (lcs_idx >= lcs.length || actual_lines[act_idx] != lcs[lcs_idx])
        # Line only in actual (extra) - show in green
        line_content = show_whitespace ? format_whitespace(actual_lines[act_idx], :added) : h(actual_lines[act_idx])
        result << %(<span class="diff-added">+#{line_content}<span class="diff-newline">↵</span></span>\n)
        act_idx += 1
      end
    end

    # Show trailing newline difference
    if expected_has_trailing_newline != actual_has_trailing_newline
      if expected_has_trailing_newline && !actual_has_trailing_newline
        result << %(<span class="diff-removed diff-no-newline">\\ No newline at end of actual output</span>\n)
      elsif !expected_has_trailing_newline && actual_has_trailing_newline
        result << %(<span class="diff-added diff-no-newline">\\ Extra newline at end of actual output</span>\n)
      end
    end

    result << '</pre>'
    result << '</div>'
    result.join.html_safe
  end

  private

  # Format whitespace characters to be visible
  # type can be :removed, :added, or nil (for context)
  def format_whitespace(text, type = nil)
    result = h(text)

    # Replace spaces with visible character
    space_class = case type
                  when :removed then 'ws-space ws-removed'
                  when :added then 'ws-space ws-added'
                  else 'ws-space'
                  end
    result = result.gsub(' ', %(<span class="#{space_class}">·</span>))

    # Replace tabs with visible character
    tab_class = case type
                when :removed then 'ws-tab ws-removed'
                when :added then 'ws-tab ws-added'
                else 'ws-tab'
                end
    result = result.gsub("\t", %(<span class="#{tab_class}">→</span>))

    result
  end

  # Compute Longest Common Subsequence
  def longest_common_subsequence(arr1, arr2)
    m = arr1.length
    n = arr2.length
    dp = Array.new(m + 1) { Array.new(n + 1, 0) }

    (1..m).each do |i|
      (1..n).each do |j|
        if arr1[i - 1] == arr2[j - 1]
          dp[i][j] = dp[i - 1][j - 1] + 1
        else
          dp[i][j] = [dp[i - 1][j], dp[i][j - 1]].max
        end
      end
    end

    # Backtrack to find LCS
    lcs = []
    i, j = m, n
    while i > 0 && j > 0
      if arr1[i - 1] == arr2[j - 1]
        lcs.unshift(arr1[i - 1])
        i -= 1
        j -= 1
      elsif dp[i - 1][j] > dp[i][j - 1]
        i -= 1
      else
        j -= 1
      end
    end

    lcs
  end

  public

  # Render markdown with syntax highlighting
  def markdown(text)
    return '' if text.blank?

    # Configure Kramdown with Rouge for syntax highlighting
    options = {
      input: 'GFM', # GitHub Flavored Markdown
      syntax_highlighter: 'rouge',
      syntax_highlighter_opts: {
        css_class: 'highlight',
        default_lang: 'text'
      },
      hard_wrap: false,
      math_engine: nil # Disable kramdown's built-in math (we'll use KaTeX in JS)
    }

    html = Kramdown::Document.new(text, options).to_html

    # Replace hardcoded /assets/ image paths with Rails asset_path helper
    # Only needed in production where assets are fingerprinted
    if Rails.env.production?
      html.gsub!(%r{src=["']/assets/([^"']+)["']}) do |match|
        image_filename = Regexp.last_match(1)
        "src=\"#{image_path(image_filename)}\""
      end
    end

    html.html_safe
  end

  # Status icons for submissions
  def status_icon(status)
    case status.downcase
    when 'accepted'
      '✓'
    when /wrong answer/
      '✗'
    when 'running', 'queued', 'enqueued', 'compiling'
      '⏱'
    when /time limit exceeded/
      '⏱'
    when /memory limit exceeded/
      '💾'
    when /compilation error/
      '🔧'
    when /runtime error/
      '⚠'
    when /presentation error/
      '~'
    else
      '•'
    end
  end

  # Map language names to Prism.js class names
  def language_class(language_name)
    mapping = {
      'Python 3' => 'python',
      'Python' => 'python',
      'Python3' => 'python',
      'Javascript (NodeJS)' => 'javascript',
      'JavaScript' => 'javascript',
      'Node.js' => 'javascript',
      'Ruby' => 'ruby',
      'C' => 'c',
      'C++11' => 'cpp',
      'C++' => 'cpp',
      'C++ 11' => 'cpp',
      'Java' => 'java',
      'Go' => 'go'
    }
    mapping[language_name] || 'text'
  end
end
