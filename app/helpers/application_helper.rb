module ApplicationHelper
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

  def season_url_for(season)
    "//#{season.slug}.#{request.domain}#{":#{request.port}" unless [ 80, 443 ].include?(request.port)}"
  end
end
