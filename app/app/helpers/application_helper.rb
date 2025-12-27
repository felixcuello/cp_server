# frozen_string_literal: true

module ApplicationHelper
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
    when 'wrong answer', /wrong answer/
      '✗'
    when 'running', 'queued', 'enqueued', 'compiling'
      '⏱'
    when 'time limit exceeded'
      '⏱'
    when 'memory limit exceeded'
      '💾'
    when 'compilation error'
      '🔧'
    when 'runtime error'
      '⚠'
    when 'presentation error'
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
