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
    
    Kramdown::Document.new(text, options).to_html.html_safe
  end
end
