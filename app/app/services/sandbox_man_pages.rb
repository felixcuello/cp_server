# frozen_string_literal: true

# Reads pre-built mandoc HTML from SANDBOX_MAN_ROOT.
# Lookups must stay on the allowlist and must never shell out.
class SandboxManPages
  SECTIONS = %w[2 3 7 2p 3p].freeze
  SECTION_PREFERENCE = %w[3 2 7 3p 2p].freeze
  SOURCE_SECTION_MAP = {
    "2" => "2",
    "3" => "3",
    "7" => "7",
    "2p" => "2p",
    "3p" => "3p",
    "2posix" => "2p",
    "3posix" => "3p"
  }.freeze
  PAGE_NAME = /\A[A-Za-z0-9_+][A-Za-z0-9._+-]*\z/
  HREF_RE = /href="[^"]*?([A-Za-z0-9._+-]+)\.(\d+[a-z]*)(?:\.html)?"/i
  MAN_HREF_RE = /href="man:([A-Za-z0-9._+-]+)\((\d+[a-z]*)\)"/i
  ALLOWED_TAGS = %w[
    a h1 h2 h3 h4 h5 h6 p pre code div span
    table thead tbody tfoot tr td th
    dl dt dd ul ol li br em strong b i var
    sup sub blockquote section header small
  ].freeze
  ALLOWED_ATTRIBUTES = %w[
    href class id title
    data-man-name data-man-section
  ].freeze

  def initialize(root: self.class.root, locale: I18n.locale)
    @root = Pathname.new(root)
    @locale = normalize_locale(locale)
  end

  def self.root
    ENV.fetch("SANDBOX_MAN_ROOT", "/usr/share/sandbox-man")
  end

  def self.topics_config
    path = Rails.root.join("config/sandbox_man_topics.yml")
    return {} unless path.exist?

    YAML.load_file(path) || {}
  end

  # Combined page list plus topic groups for the docs drawer.
  def index
    pages = merged_pages
    { pages: pages, topics: resolved_topics(pages) }
  end

  # One man page as sanitized HTML, English fallback, or missing.
  def page(section:, name:)
    return { error: "invalid" } unless valid_section?(section) && valid_name?(name)

    html, fallback = read_html(section, name)
    return { missing: true, name: name, section: section } if html.blank?

    {
      missing: false,
      fallback: fallback,
      name: name,
      section: section,
      title: title_for(name, section),
      html: sanitize(rewrite_man_links(html))
    }
  end

  private

  def merged_pages
    english = load_index("en")
    return english if @locale == "en"

    localized = load_index(@locale)
    seen = {}
    localized.each { |page| seen[[ page["name"], page["section"] ]] = true }
    extra = english.filter_map do |page|
      next if seen[[ page["name"], page["section"] ]]

      page.merge("fallback" => true)
    end
    localized + extra
  end

  def resolved_topics(pages)
    by_key = pages.index_by { |page| [ page["name"], page["section"] ] }

    self.class.topics_config.map do |key, refs|
      {
        "key" => key.to_s,
        "label" => I18n.t("sandbox.man_topics.#{key}", default: key.to_s.humanize),
        "pages" => Array(refs).map { |ref| resolve_topic_ref(ref, by_key) }
      }
    end
  end

  def resolve_topic_ref(ref, by_key)
    if ref.is_a?(Hash)
      name = ref["name"].to_s
      section = ref["section"]&.to_s
    else
      name = ref.to_s
      section = nil
    end

    if section.present?
      found = by_key[[ name, section ]]
      return { "name" => name, "section" => section, "missing" => found.blank? }
    end

    match = SECTION_PREFERENCE.filter_map { |pref| by_key[[ name, pref ]] }.first
    if match
      { "name" => match["name"], "section" => match["section"], "missing" => false }
    else
      { "name" => name, "section" => nil, "missing" => true }
    end
  end

  def load_index(locale)
    path = @root.join(locale, "index.json")
    return [] unless path.file?

    data = JSON.parse(path.read)
    Array(data).map do |page|
      {
        "name" => page["name"].to_s,
        "section" => page["section"].to_s,
        "title" => page["title"].to_s
      }
    end
  rescue JSON::ParserError
    []
  end

  def read_html(section, name)
    localized = html_path(@locale, section, name)
    return [ localized.read, false ] if localized&.file?

    if @locale != "en"
      english = html_path("en", section, name)
      return [ english.read, true ] if english&.file?
    end

    [ nil, false ]
  end

  def html_path(locale, section, name)
    candidate = @root.join(locale, section, "#{name}.html")
    return nil unless path_inside_root?(candidate)

    candidate
  end

  def path_inside_root?(candidate)
    root_real = @root.realpath
    cand_real = candidate.realpath
    cand_real.to_s.start_with?(root_real.to_s + File::SEPARATOR)
  rescue Errno::ENOENT
    candidate.expand_path.to_s.start_with?(@root.expand_path.to_s + File::SEPARATOR)
  end

  # Turn mandoc and groff cross-references into in-app man links.
  def rewrite_man_links(html)
    rewritten = html.gsub(HREF_RE) { man_link_attrs(Regexp.last_match(1), Regexp.last_match(2)) }
    rewritten.gsub(MAN_HREF_RE) { man_link_attrs(Regexp.last_match(1), Regexp.last_match(2)) }
  end

  def man_link_attrs(name, source_section)
    section = SOURCE_SECTION_MAP[source_section.downcase] || source_section
    %(href="#" data-man-name="#{ERB::Util.html_escape(name)}" data-man-section="#{ERB::Util.html_escape(section)}")
  end

  def title_for(name, section)
    merged_pages.find { |page| page["name"] == name && page["section"] == section }&.fetch("title", "") || ""
  end

  def sanitize(html)
    ActionController::Base.helpers.sanitize(
      html,
      tags: ALLOWED_TAGS,
      attributes: ALLOWED_ATTRIBUTES
    )
  end

  def valid_section?(section)
    SECTIONS.include?(section.to_s)
  end

  def valid_name?(name)
    value = name.to_s
    return false if value == "." || value == ".." || value.include?("..")

    PAGE_NAME.match?(value)
  end

  def normalize_locale(locale)
    value = locale.to_s
    return "es" if value.start_with?("es")

    "en"
  end
end
