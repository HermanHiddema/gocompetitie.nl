module ApplicationHelper
  FRACTION_LABELS = {
    2 => { 1 => "½" },
    3 => { 1 => "⅓", 2 => "⅔" },
    4 => { 1 => "¼", 3 => "¾" },
    5 => { 1 => "⅕", 2 => "⅖", 3 => "⅗", 4 => "⅘" },
    6 => { 1 => "⅙", 5 => "⅚" },
    8 => { 1 => "⅛", 3 => "⅜", 5 => "⅝", 7 => "⅞" }
  }.freeze

  MARKDOWN_RENDERER = Redcarpet::Render::HTML.new(
    filter_html: true, hard_wrap: true, link_attributes: { rel: "nofollow" }
  )

  MARKDOWN_EXTENSIONS = {
    autolink: true, fenced_code_blocks: true, lax_spacing: true,
    no_intra_emphasis: true, strikethrough: true, superscript: true
  }.freeze

  def markdown(text)
    return if text.blank?

    tag.div class: "markdown" do
      sanitize Redcarpet::Markdown.new(MARKDOWN_RENDERER, MARKDOWN_EXTENSIONS).render(text)
    end
  end

  def format_fraction(value)
    return if value.nil?

    number = value.to_f
    magnitude = number.abs
    whole = magnitude.truncate
    fraction = magnitude - whole
    sign = number.negative? ? "-" : ""

    return "#{sign}#{whole}" if fraction.zero?

    FRACTION_LABELS.each do |denominator, labels|
      numerator = (fraction * denominator).round
      next unless labels[numerator] && (fraction - numerator.fdiv(denominator)).abs < Float::EPSILON * 10

      return "#{sign}#{whole unless whole.zero?}#{labels[numerator]}"
    end

    number.to_s
  end

  def format_match_result(match)
    [match.black_points, match.white_points].map { |points| format_fraction(points) || "?" }.join("-")
  end

  # Only links out to http(s) urls, so a stored javascript: url can never be
  # turned into a link.
  def external_link_to(url, name = nil, **options)
    return if url.blank?

    uri = URI.parse(url.to_s) rescue nil
    name ||= url

    if uri.is_a?(URI::HTTP) && uri.host.present?
      link_to name, uri.to_s, rel: "nofollow noopener", target: "_blank", **options
    else
      name
    end
  end

  # Clubs and venues have no season of their own, so links to them carry the
  # season of the current page in the path.
  def season_url_options
    { season_slug: current_season&.slug }
  end

  def nav_link_to(name, path, **options)
    classes = "rounded-md px-3 py-2 text-sm font-medium transition hover:bg-slate-700 hover:text-white"
    classes += current_page?(path) ? " bg-slate-900 text-white" : " text-slate-200"

    link_to name, path, class: classes, **options
  end

  def button_link_to(name, path, style: :primary, **options)
    link_to name, path, class: button_classes(style), **options
  end

  def button_classes(style = :primary)
    base = "inline-flex items-center justify-center rounded-md px-4 py-2 text-sm font-semibold shadow-sm transition cursor-pointer"

    case style
    when :primary then "#{base} bg-slate-800 text-white hover:bg-slate-700"
    when :secondary then "#{base} bg-white text-slate-800 ring-1 ring-slate-300 hover:bg-slate-100"
    when :danger then "#{base} bg-red-700 text-white hover:bg-red-600"
    else base
    end
  end

  def field_classes
    "block w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-slate-900 shadow-sm focus:border-slate-500 focus:outline-none focus:ring-1 focus:ring-slate-500"
  end

  def label_classes
    "block text-sm font-medium text-slate-700 mb-1"
  end
end
