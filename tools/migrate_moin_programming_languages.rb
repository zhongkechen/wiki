# frozen_string_literal: true

require "fileutils"
require "json"
require "pathname"
require "tmpdir"

DEFAULT_SOURCE_ROOT = File.expand_path("../mywiki/data/pages", __dir__)
SOURCE_ROOT = File.expand_path(ENV.fetch("MOIN_SOURCE_ROOT", DEFAULT_SOURCE_ROOT))
OUTPUT_ROOT = File.expand_path("../old", __dir__)
COURSE_NAME = "程序设计语言"
COURSE_TITLE = "程序设计语言"
COURSE_OUTPUT = File.join(OUTPUT_ROOT, COURSE_NAME)
SOURCE_SNAPSHOT_PATH = File.expand_path("data/moin_programming_languages_sources.json", __dir__)
SOURCE_ASSET_ROOT = File.join(COURSE_OUTPUT, "assets")
SHARED_PAGE_LINKS = {
  "C" => "高级语言程序设计课程/C.qmd",
  "Python游戏开发基础" => "Python游戏开发基础.qmd",
  "C++集成开发环境" => "C++集成开发环境.qmd",
  "面向对象程序设计课程" => "面向对象程序设计课程.qmd",
  "熟悉MATLAB环境" => "数字图像处理/熟悉MATLAB环境.qmd"
}.freeze
SOURCE_SNAPSHOT =
  if File.exist?(SOURCE_SNAPSHOT_PATH)
    JSON.parse(File.read(SOURCE_SNAPSHOT_PATH, encoding: "UTF-8"))
  else
    {}
  end

IMAGE_EXTENSIONS = %w[.bmp .gif .jpeg .jpg .png .svg .tif .tiff .webp].freeze
NORMALIZED_TEXT_ATTACHMENT_EXTENSIONS = %w[.cc .htm .py].freeze
BLOCK_TOKEN_PATTERN = /@@MOIN_BLOCK_(\d+)@@/
TABLE_HEADER_FIRST_CELLS = %w[Array 姓名 物品].freeze
SECTION_NUMBER_PRAGMA_PATTERN = /^#pragma section-numbers \d+[ \t]*\r?$/
SOURCE_TEXT_REPLACEMENTS = {
  "Python" => {
    "Learning to Program: attachment: " \
      "http://www.freenetpages.co.uk/hp/alan.gauld/" =>
      "[[http://www.freenetpages.co.uk/hp/alan.gauld/|" \
        "Learning to Program]]"
  }
}.freeze
LEGACY_HTML_PAGE_LINKS = {
  "Vector.html" => "STL编程指南/vector",
  "List.html" => "STL编程指南/list",
  "Slist.html" => "STL编程指南/slist",
  "Deque.html" => "STL编程指南/deque",
  "ForwardContainer.html" => "STL编程指南/Forward Container",
  "RandomAccessContainer.html" => "STL编程指南/Random Access Container",
  "FrontInsertionSequence.html" => "STL编程指南/Front Insertion Sequence",
  "BackInsertionSequence.html" => "STL编程指南/Back Insertion Sequence",
  "ReversibleContainer.html" => "STL编程指南/Reversible Container",
  "DefaultConstructible.html" => "STL编程指南/DefaultConstructible.html",
  "EqualityComparable.html" => "STL编程指南/EqualityComparable.html",
  "InputIterator.html" => "STL编程指南/STL概述/InputIterator",
  "Iterators.html" => "STL编程指南/Iterators.html",
  "LessThanComparable.html" => "STL编程指南/LessThanComparable.html",
  "swap.html" => "STL编程指南/swap.html",
  "Allocators.html" => "STL编程指南/STL概述/Allocator",
  "copy.html" => "STL编程指南/copy.html",
  "ostream_iterator.html" => "STL编程指南/STL概述/ostream_iterator",
  "index.html" => "STL编程指南"
}.freeze
LEGACY_HTML_SOURCE_OUTPUTS = {
  "STL编程指南/DefaultConstructible.html" =>
    "STL编程指南/DefaultConstructible",
  "STL编程指南/EqualityComparable.html" =>
    "STL编程指南/EqualityComparable",
  "STL编程指南/Iterators.html" =>
    "STL编程指南/Iterators",
  "STL编程指南/LessThanComparable.html" =>
    "STL编程指南/LessThanComparable",
  "STL编程指南/swap.html" =>
    "STL编程指南/swap",
  "STL编程指南/copy.html" =>
    "STL编程指南/copy"
}.freeze
UNAVAILABLE_LEGACY_HTML_LINKS = %w[
  ../../cpplinks/blast.html
  ../../cpplinks/compilers.html
  ../../cpplinks/esc99.html
  ../../cpplinks/learn.html
  /cgi-bin/feedback/index.cgi
  /company_info/privacy.html
  /company_info/terms.html
  /company_info/trademarks/
  deque
  deque.h
].freeze
UNAVAILABLE_LEGACY_HTML_IMAGES = %w[
  /images/common/sgilogo_small.gif
  containers.gif
  type.gif
].freeze
LEGACY_HEADING_IDS = {
  "PythonImageLibrary中文手册" => {
    "open" => "image-open-function",
    "getbands" => "image-getbands-method",
    "mode" => "image-mode-attribute",
    "size" => "image-size-attribute",
    "info" => "image-info-attribute",
    "offset" => [nil, "imagechops-offset"].freeze,
    "图像文件格式" => "pil-image-formats",
    "编写自己的文件解码器" => "pil-custom-decoder"
  }.freeze
}.freeze
LEGACY_RELATIVE_LINK_TARGETS = {
  "PythonImageLibrary中文手册" => {
    "image.htm#image-getbands-method" => "#image-getbands-method",
    "image.htm#image-mode-attribute" => "#image-mode-attribute",
    "image.htm#image-size-attribute" => "#image-size-attribute",
    "image.htm#image-info-attribute" => "#image-info-attribute",
    "formats.htm" => "#pil-image-formats",
    "decoder.htm" => "#pil-custom-decoder",
    "imagechops.htm#offset" => "#imagechops-offset"
  }.freeze
}.freeze

def decode_page_name(entry)
  entry.gsub(/\(([0-9a-fA-F]+)\)/) do
    [$1].pack("H*").force_encoding("UTF-8")
  end
end

PAGE_INDEX =
  if Dir.exist?(SOURCE_ROOT)
    Dir.children(SOURCE_ROOT).to_h do |entry|
      [decode_page_name(entry), entry]
    end
  else
    {}
  end

AVAILABLE_PAGE_NAMES = (PAGE_INDEX.keys + SOURCE_SNAPSHOT.keys).uniq.freeze

if PAGE_INDEX.empty? && SOURCE_SNAPSHOT.empty?
  raise <<~MESSAGE
    MoinMoin source data was not found.
    Set MOIN_SOURCE_ROOT to a data/pages directory or restore #{SOURCE_SNAPSHOT_PATH}.
  MESSAGE
end

def page_directory(name)
  entry = PAGE_INDEX[name]
  entry && File.join(SOURCE_ROOT, entry)
end

def snapshot_record(name)
  record = SOURCE_SNAPSHOT[name]
  return {} unless record

  record.is_a?(Hash) ? record : { "source" => record }
end

def page_current_revision(name)
  directory = page_directory(name)
  return snapshot_record(name)["current_revision"] unless directory

  current_path = File.join(directory, "current")
  return nil unless File.exist?(current_path)

  File.read(current_path).strip
end

def page_revision(name)
  directory = page_directory(name)
  return snapshot_record(name)["revision"] unless directory

  revisions_directory = File.join(directory, "revisions")
  return nil unless Dir.exist?(revisions_directory)

  current_revision = page_current_revision(name)
  current_path = current_revision && File.join(revisions_directory, current_revision)
  return current_revision if current_path && File.file?(current_path)

  Dir.children(revisions_directory).select do |revision|
    File.file?(File.join(revisions_directory, revision))
  end.max
end

def page_source(name)
  directory = page_directory(name)
  if directory
    revision = page_revision(name)
    return "" unless revision

    revision_path = File.join(directory, "revisions", revision)
    return File.read(revision_path, encoding: "UTF-8", invalid: :replace)
  end

  snapshot_record(name).fetch("source", "")
end

def page_has_readable_revision?(name)
  directory = page_directory(name)
  unless directory
    record = snapshot_record(name)
    return false if record.empty?

    return true if record["revision"]

    return !record.fetch("source", "").strip.empty?
  end

  !page_revision(name).nil?
end

def page_uses_fallback_revision?(name)
  current_revision = page_current_revision(name)
  selected_revision = page_revision(name)
  current_revision && selected_revision && current_revision != selected_revision
end

def normalize_page_target(target, owner)
  clean_target = target.sub(/\A\^/, "")
  return "#{owner}#{clean_target}" if clean_target.start_with?("/")
  return clean_target unless clean_target.start_with?(".")

  owner_parts = owner.split("/")
  while clean_target.start_with?("../")
    owner_parts.pop
    clean_target = clean_target.delete_prefix("../")
  end
  clean_target = clean_target.delete_prefix("./")
  (owner_parts + [clean_target]).reject(&:empty?).join("/")
end

def linked_page_names(source, owner:)
  source.scan(/\[\[([^\]]+)\]\]/).flatten.filter_map do |raw|
    next if raw.start_with?("attachment:")
    next if raw.match?(%r{\A(?:https?|ftp|mailto):}) || raw.start_with?("#")

    normalize_page_target(raw.split("|", 2).first, owner)
  end.uniq
end

def included_page_names(source, owner:)
  source.scan(/<<Include\(\^?([^,)]+)(?:,[^)]*)?\)>>/).flatten.filter_map do |target|
    next if target.include?(".*")

    normalize_page_target(target, owner)
  end.uniq
end

def matching_page_names(pattern, owner)
  if pattern.start_with?("/") && !pattern.match?(/[.*+?\[\](){}|]/)
    target = normalize_page_target(pattern, owner)
    return AVAILABLE_PAGE_NAMES.include?(target) ? [target] : []
  end

  expression =
    if pattern.start_with?("/")
      "^#{Regexp.escape(owner)}#{pattern}"
    else
      pattern
    end
  matcher =
    begin
      Regexp.new(expression)
    rescue RegexpError
      /#{Regexp.escape(expression)}/
    end
  AVAILABLE_PAGE_NAMES.select { |page_name| page_name.match?(matcher) }.sort
end

def page_list_page_names(source, owner:)
  patterns = source.scan(/<<PageList\(([^)]+)\)>>/).flatten
  patterns.concat(
    source.scan(/<<Include\(([^,)]+),[^)]*titlesonly[^)]*\)>>/).flatten
  )
  patterns.concat(
    source.scan(/<<Include\(([^,)]+\.\*[^,)]*)(?:,[^)]*)?\)>>/).flatten
  )
  patterns.flat_map { |pattern| matching_page_names(pattern, owner) }.uniq.sort
end

COURSE_SOURCE = page_source(COURSE_NAME)
direct_pages = linked_page_names(COURSE_SOURCE, owner: COURSE_NAME).reject do |page_name|
  SHARED_PAGE_LINKS.key?(page_name)
end
primary_pages = (
  direct_pages +
  ["Matlab"] +
  page_list_page_names(COURSE_SOURCE, owner: COURSE_NAME) +
  LEGACY_HTML_SOURCE_OUTPUTS.keys
).uniq
queue = primary_pages.select { |page_name| page_has_readable_revision?(page_name) }

until queue.empty?
  page_name = queue.shift
  source = page_source(page_name)
  descendants = linked_page_names(source, owner: page_name)
  descendants.concat(included_page_names(source, owner: page_name))
  descendants.concat(page_list_page_names(source, owner: page_name))

  descendants.each do |target|
    next if target == COURSE_NAME || primary_pages.include?(target)
    next if SHARED_PAGE_LINKS.key?(target)
    related_missing_page = target.start_with?(
      "C++:",
      "Python介绍/",
      "SICP的Python实现/",
      "STL编程指南/"
    )
    next unless AVAILABLE_PAGE_NAMES.include?(target) || related_missing_page

    primary_pages << target
    queue << target if page_has_readable_revision?(target)
  end
end

PRIMARY_PAGES = primary_pages.freeze
MIGRATED_PAGES = ([COURSE_NAME] + PRIMARY_PAGES).uniq.freeze
AUXILIARY_SOURCE_PAGE_NAMES = MIGRATED_PAGES.filter_map do |page_name|
  next unless page_source(page_name).include?("<<PageComment2")

  comment_page = "#{page_name}/PageCommentData"
  comment_page if page_has_readable_revision?(comment_page)
end.freeze
SOURCE_PAGE_NAMES = (MIGRATED_PAGES + AUXILIARY_SOURCE_PAGE_NAMES).uniq.freeze

if PAGE_INDEX.any?
  snapshot = SOURCE_PAGE_NAMES.to_h do |page_name|
    [
      page_name,
      {
        "source" => page_source(page_name),
        "revision" => page_revision(page_name),
        "current_revision" => page_current_revision(page_name)
      }
    ]
  end
  FileUtils.mkdir_p(File.dirname(SOURCE_SNAPSHOT_PATH))
  File.write(SOURCE_SNAPSHOT_PATH, JSON.pretty_generate(snapshot) + "\n")
end

def qmd_front_matter(title, number_sections: false)
  escaped = title.gsub("\\", "\\\\").gsub('"', '\\"')
  number_sections_line = number_sections ? "number-sections: true\n" : ""
  <<~YAML
    ---
    title: "#{escaped}"
    #{number_sections_line}lang: zh
    toc: true
    format:
      html:
        code-copy: true
        html-math-method: mathjax
    ---
  YAML
end

def page_output_name(page_name)
  LEGACY_HTML_SOURCE_OUTPUTS.fetch(page_name, page_name)
end

def current_output_path(owner, context)
  context == :course ? "#{COURSE_NAME}.qmd" : "#{COURSE_NAME}/#{page_output_name(owner)}.qmd"
end

def relative_output_path(destination, owner, context)
  current_directory = File.dirname(current_output_path(owner, context))
  Pathname(destination).relative_path_from(Pathname(current_directory)).to_s
end

def page_link(target, owner, context)
  clean_target = normalize_page_target(target, owner)

  if (shared_page = SHARED_PAGE_LINKS[clean_target])
    relative_output_path(shared_page, owner, context)
  elsif clean_target == COURSE_NAME
    relative_output_path("#{COURSE_NAME}.qmd", owner, context)
  elsif MIGRATED_PAGES.include?(clean_target)
    relative_output_path(
      "#{COURSE_NAME}/#{page_output_name(clean_target)}.qmd",
      owner,
      context
    )
  else
    relative_output_path("#{clean_target}.html", owner, context)
  end
end

def asset_target(owner, filename, context)
  clean_filename = filename.sub(%r{\A\.\./}, "")
  parts = clean_filename.split("/", 2)

  if parts.length == 2 && MIGRATED_PAGES.include?(parts.first)
    owner = parts.first
    clean_filename = parts.last
  end

  destination = "#{COURSE_NAME}/assets/#{owner}/#{clean_filename}"
  relative_output_path(destination, owner, context)
end

def markdown_target(path)
  "<#{path}>"
end

def attachment_markup(spec, owner, context, image:)
  target = asset_target(owner, spec, context)
  label = File.basename(spec)
  if image && IMAGE_EXTENSIONS.include?(File.extname(label).downcase)
    "![#{label}](#{markdown_target(target)})"
  else
    "[#{label}](#{markdown_target(target)})"
  end
end

def convert_link(raw, owner, context)
  target, label = raw.split("|", 2)
  label ||= target.sub(%r{\A(?:\.\./|/)+}, "")

  if target.start_with?("attachment:")
    spec = target.delete_prefix("attachment:")
    visible = label.start_with?("attachment:") ? File.basename(spec) : label
    path = asset_target(owner, spec, context)
    return "[#{visible}](#{markdown_target(path)})"
  end

  return "[#{label}](#{target})" if target.match?(%r{\A(?:https?|ftp|mailto):})
  return "[#{label}](#{target})" if target.start_with?("#")

  "[#{label}](#{markdown_target(page_link(target, owner, context))})"
end

def normalize_latex(content)
  formula = content.lines.map(&:rstrip).join("\n").strip
  formula = formula.delete_prefix("$$").delete_suffix("$$").strip if formula.start_with?("$$") && formula.end_with?("$$")
  formula = formula.delete_prefix("$").delete_suffix("$").strip if formula.start_with?("$") && formula.end_with?("$")
  formula
end

def markdown_code_span(content)
  code = content.strip
  return "" if code.empty?

  longest_run = code.scan(/`+/).map(&:length).max || 0
  delimiter = "`" * (longest_run + 1)
  padding = code.start_with?("`") || code.end_with?("`") ? " " : ""
  "#{delimiter}#{padding}#{code}#{padding}#{delimiter}"
end

def normalize_code_line(line)
  stripped = line.rstrip
  indentation = stripped[/\A[ \t]+/]
  return stripped unless indentation&.include?("\t")

  width = indentation.each_char.reduce(0) do |column, character|
    character == "\t" ? ((column / 4) + 1) * 4 : column + 1
  end
  (" " * width) + stripped.delete_prefix(indentation)
end

def legacy_html_image_source(tag)
  tag[/\bsrc\s*=\s*["']([^"']+)["']/i, 1]
end

def protect_cpp_operator_signatures(text)
  text.gsub(/operator\[\](?=\()/, "operator&#91;&#93;")
end

def normalize_legacy_html(body, owner:, context:)
  normalized = body.dup
  normalized.gsub!(%r{<head\b[^>]*>.*?</head>}im, "")
  normalized.gsub!(%r{</?(?:html|body)\b[^>]*>}i, "")
  normalized.gsub!(%r{\bhttp://docs\.google\.com/}, "https://docs.google.com/")
  normalized.gsub!(%r{<a\b[^>]*>\s*(<img\b[^>]*>)\s*</a>}im) do |match|
    source = legacy_html_image_source(Regexp.last_match(1))
    UNAVAILABLE_LEGACY_HTML_IMAGES.include?(source) ? "" : match
  end
  normalized.gsub!(%r{<img\b[^>]*>}im) do |tag|
    source = legacy_html_image_source(tag)
    UNAVAILABLE_LEGACY_HTML_IMAGES.include?(source) ? "" : tag
  end
  normalized.gsub!(/(\bhref\s*=\s*)(["'])([^"']+)\2/i) do |attribute|
    prefix = Regexp.last_match(1)
    quote = Regexp.last_match(2)
    target = Regexp.last_match(3)
    next "" if UNAVAILABLE_LEGACY_HTML_LINKS.include?(target)

    page_name = LEGACY_HTML_PAGE_LINKS[target]
    next attribute unless page_name

    path = page_link(page_name, owner, context).sub(/\.qmd\z/, ".html")
    "#{prefix}#{quote}#{path}#{quote}"
  end
  protect_cpp_operator_signatures(normalized).strip
end

def convert_blocks(text, owner:, context:)
  text = text.gsub(/\{\{\{\s*\n#!([^\n]+)\n(?=\{\{\{\s*\n#!\1\n)/, "")
  blocks = []
  inline = []
  converted = text.gsub(/\{\{\{(.*?)\}\}\}/m) do
    content = Regexp.last_match(1)
    unless content.include?("\n")
      token = "@@MOIN_INLINE_#{inline.length}@@"
      inline << markdown_code_span(content)
      next token
    end

    content = content.sub(/\A[ \t]*\n/, "")
    language = nil
    if (language_line = content.match(/\A#!([^\n]+)\n/))
      language = language_line[1].strip
      content = content.delete_prefix(language_line[0])
    end
    body = content.lines.map { |line| normalize_code_line(line) }.join("\n").rstrip
    rendered =
      if language == "latex"
        "$$\n#{normalize_latex(body)}\n$$"
      elsif %w[html raw].include?(language)
        normalize_legacy_html(body, owner: owner, context: context)
      else
        fence_language = language.to_s.downcase.gsub(/\s.*\z/, "")
        fence_language = {
          "c++" => "cpp",
          "cplusplus" => "cpp",
          "cpluscplus" => "cpp"
        }.fetch(fence_language, fence_language)
        "```#{fence_language}\n#{body}\n```"
      end
    token = "@@MOIN_BLOCK_#{blocks.length}@@"
    blocks << rendered
    token
  end

  [converted, blocks, inline]
end

def add_display_math_block(source, blocks)
  source.gsub(/<<latex\((.*?)\)>>/m) do
    formula = Regexp.last_match(1).strip
    if formula.start_with?("$$") && formula.end_with?("$$")
      token = "@@MOIN_BLOCK_#{blocks.length}@@"
      blocks << "$$\n#{normalize_latex(formula)}\n$$"
      token
    else
      "$#{normalize_latex(formula)}$"
    end
  end
end

def attachment_names(owner)
  source_directory = page_directory(owner)
  source_attachments = source_directory && File.join(source_directory, "attachments")
  if source_attachments && Dir.exist?(source_attachments)
    return Dir.children(source_attachments).select do |filename|
      File.file?(File.join(source_attachments, filename))
    end.sort
  end

  snapshot_assets = File.join(SOURCE_ASSET_ROOT, owner)
  return [] unless Dir.exist?(snapshot_assets)

  Dir.children(snapshot_assets).select do |filename|
    File.file?(File.join(snapshot_assets, filename))
  end.sort
end

def render_attach_list(owner)
  attachment_names(owner).map do |filename|
    " * [[attachment:#{filename}]]"
  end.join("\n")
end

def include_unlisted_attachments(source, owner)
  names = attachment_names(owner)
  return source if names.empty?
  return source if source.include?("<<AttachList>>")

  referenced = source.scan(/attachment:([^}\]\n]+)/).flatten.map do |spec|
    spec.split("|", 2).first.strip
  end
  unlisted = names - referenced
  return source if unlisted.empty?

  attachment_list = unlisted.map { |filename| " * [[attachment:#{filename}]]" }.join("\n")
  [source.rstrip, "", "= 附件 =", attachment_list, ""].join("\n")
end

def external_image_markup(url, label)
  visible = label.to_s.empty? ? File.basename(url.split(/[?#]/, 2).first) : label
  "![#{visible}](#{url})"
end

def mailto_markup(spec)
  address = spec.strip
                .gsub(/\s+AT\s+/i, "@")
                .gsub(/\s+DOT\s+/i, ".")
                .delete(" ")
  "[#{address}](mailto:#{address})"
end

def page_comments(owner)
  source = page_source("#{owner}/PageCommentData")
  source.scan(/\{\{\{\s*\n(.*?)\n\}\}\}/m).filter_map do |match|
    lines = match.first.gsub("\r\n", "\n").lines.map(&:rstrip)
    next if lines.length < 5

    author = lines[1].strip
    timestamp = lines[2].strip
    body = lines.drop(4).join("\n").strip
    next if body.empty?

    { author: author, timestamp: timestamp, body: body }
  end
end

def render_page_comments(owner)
  page_comments(owner).map do |comment|
    body = comment[:body].lines.map { |line| line.strip.empty? ? ">" : "> #{line.rstrip}" }.join("\n")
    [
      "> **#{comment[:author]}** · #{comment[:timestamp]}",
      ">",
      body
    ].join("\n")
  end.join("\n\n")
end

def render_random_quote(page_name)
  quote = page_source(page_name).lines.find { |line| line.match?(/^\s+\*\s+/) }
  return "程序设计竞赛资料" unless quote

  quote.sub(/^\s+\*\s+/, "").strip
end

def render_page_list(pattern, owner)
  matching_page_names(pattern, owner).map do |page_name|
    " * [[#{page_name}]]"
  end.join("\n")
end

def render_content_with_blocks(content, blocks, first_prefix: "", continuation_prefix: "")
  parts = content.split(BLOCK_TOKEN_PATTERN, -1)
  lines = []
  current = first_prefix.dup

  parts.each_with_index do |part, index|
    if index.even?
      next if part.empty?

      current << part
      next
    end

    block = blocks.fetch(part.to_i)
    lines << current.rstrip unless current.strip.empty?
    lines << "" unless lines.empty? || lines.last.empty?
    block.each_line do |block_line|
      stripped = block_line.rstrip
      lines << (stripped.empty? ? "" : "#{continuation_prefix}#{stripped}")
    end
    lines << ""
    current = continuation_prefix.dup
  end

  lines << current.rstrip unless current.strip.empty?
  lines.pop while lines.last == ""
  lines
end

def append_blank_line(result)
  result << "" unless result.empty? || result.last.empty?
end

def table_cells(line)
  body = line.strip.delete_prefix("||").delete_suffix("||")
  body.split("||", -1).map do |cell|
    cell.strip.sub(/\A(?:<[^>]+>\s*)+/, "")
  end
end

def convert_table_line(cells)
  "| #{cells.join(' | ')} |"
end

def table_header_row?(cells)
  TABLE_HEADER_FIRST_CELLS.include?(cells.first)
end

def escape_plain_moin_markup(source)
  source.gsub!(/(\|\|)\s*(?:<[^>\n]+>\s*)+/) { Regexp.last_match(1) }

  source.lines.map do |line|
    bullet = line.match(/\A(\s+)\*\s/)
    quote = line.match?(/\A>\s/)
    line = line.sub(/\A(\s+)\*/, '\1@@MOIN_BULLET@@') if bullet
    line = line.sub(/\A>/, "@@MOIN_QUOTE@@") if quote
    line = line.gsub("\\") { "\\\\" }
    line = line.gsub("*", "\\*")
    line = line.gsub(/(?<!<)<(?!<)/, "&lt;")
    line = line.gsub(/(?<!>)>(?!>)/, "&gt;")
    line.gsub("@@MOIN_BULLET@@", "*").gsub("@@MOIN_QUOTE@@", ">")
  end.join
end

def markdown_emphasis(content, marker)
  leading = content[/\A[ \t]*/]
  trailing = content[/[ \t]*\z/]
  body = content.strip
  return content if body.empty?

  "#{leading}#{marker}#{body}#{marker}#{trailing}"
end

def convert_moin_emphasis(source)
  source.lines.map do |line|
    converted = line.gsub(/'''([^'\n]*?)'''/) do
      markdown_emphasis(Regexp.last_match(1), "**")
    end
    converted.gsub(/''([^'\n]*?)''/) do
      markdown_emphasis(Regexp.last_match(1), "*")
    end
  end.join
end

def convert_moin(text, owner:, context:, expand_includes: false)
  source = text.gsub("\r\n", "\n")
  SOURCE_TEXT_REPLACEMENTS.fetch(owner, {}).each do |before, after|
    source.gsub!(before, after)
  end
  source.gsub!(/^#pragma section-numbers \d+[ \t]*\n?/, "")
  source.gsub!(/^([ \t]*)'''([^'\n]+)''[ \t]*=+[ \t]*$/) do
    "#{Regexp.last_match(1)}'''#{Regexp.last_match(2).rstrip}'''"
  end
  source.gsub!("{{{{#!", "{{{#!")
  source.gsub!(
    /(\{\{\{#!cplusplus\n#include <queue>\nnamespace std \{\n.*?\n\})\n\n(主要操作：)/m,
    "\\1\n}}}\n\n\\2"
  )
  source = include_unlisted_attachments(source, owner)

  source.gsub!(/^.*<<RandomQuote\(([^)]+)\)>>.*$/) do
    "> #{render_random_quote(Regexp.last_match(1))}"
  end

  source.gsub!(/<<PageList\(([^)]+)\)>>/) do
    render_page_list(Regexp.last_match(1), owner)
  end

  source.gsub!(/<<Include\(([^,)]+),[^)]*titlesonly[^)]*\)>>/) do
    render_page_list(Regexp.last_match(1), owner)
  end

  source.gsub!(/<<Include\(\^?([^,)]+)(?:,[^)]*)?\)>>/) do
    included_spec = Regexp.last_match(1)
    if included_spec.include?(".*")
      matches = matching_page_names(included_spec, owner)
      if expand_includes
        matches.map { |page_name| page_source(page_name) }.join("\n\n")
      else
        matches.map { |page_name| "[[#{page_name}|#{page_name}]]" }.join("\n")
      end
    elsif expand_includes
      page_source(normalize_page_target(included_spec, owner))
    else
      "[[#{included_spec}|#{included_spec}]]"
    end
  end

  source, blocks, inline = convert_blocks(source, owner: owner, context: context)
  source = add_display_math_block(source, blocks)
  source.gsub!("<<AttachList>>", render_attach_list(owner))
  source = escape_plain_moin_markup(source)
  source = protect_cpp_operator_signatures(source)

  source.gsub!(/\{\{attachment:([^}\n]+)\}\}/) do
    attachment_markup(Regexp.last_match(1), owner, context, image: true)
  end

  source.gsub!(/\{\{(https?:\/\/[^}|\n]+)(?:\|([^}|\n]*))?(?:\|[^}\n]*)?\}\}/) do
    external_image_markup(Regexp.last_match(1), Regexp.last_match(2))
  end

  source.gsub!(
    /(?<!\[)\[([^\s\[\]]+\.[A-Za-z0-9]{1,10}(?:#[^\s\[\]]+)?)(?:\s+([^\]\n]+))?\](?![\]\(])/
  ) do
    target = Regexp.last_match(1)
    label = Regexp.last_match(2) || target
    target = LEGACY_RELATIVE_LINK_TARGETS.dig(owner, target) || target
    destination = target.start_with?("#") ? target : markdown_target(target)
    "[#{label}](#{destination})"
  end

  source.gsub!(/(?<!\[)\[((?:https?|ftp|mailto):[^\s\]]+)(?:\s+([^\]]+))?\]/) do
    target = Regexp.last_match(1)
    label = Regexp.last_match(2) || target
    "[#{label}](#{target})"
  end

  source.gsub!(/\[\[([^\]]+)\]\]/) do
    convert_link(Regexp.last_match(1), owner, context)
  end

  source.gsub!("<<BR>>", "<br>")
  source.gsub!("<<和>>", "@@MOIN_SHIFT_OPERATORS@@")
  source.gsub!(/<<MailTo\(([^)]+)\)>>/) { mailto_markup(Regexp.last_match(1)) }
  source.gsub!("<<PageComment2>>") { render_page_comments(owner) }
  source.gsub!(/<<(?:TableOfContents|Navigation\([^)]*\))>>/, "")
  source.gsub!(/<<Anchor\(([^)]+)\)>>/, '<a id="\1"></a>')
  source.gsub!(/<<FootNote\(([^)]+)\)>>/, '^[\1]')
  source.gsub!(/<<[^>]+>>/, "")
  source.gsub!("@@MOIN_SHIFT_OPERATORS@@", "`<<` 和 `>>`")

  source = convert_moin_emphasis(source)

  result = []
  in_table = false
  list_indents = []
  previous_line_was_list_item = false
  heading_occurrences = Hash.new(0)

  source.each_line do |raw_line|
    line = raw_line.rstrip

    if line.match?(/\A\s*Category\S+(?:\s+Category\S+)*\s*\z/)
      next
    elsif line.start_with?("##")
      next
    elsif (heading = line.match(/^\s*(=+)\s*(.*?)\s*\1\s*$/))
      append_blank_line(result)
      level = [heading[1].length + 1, 6].min
      heading_text = heading[2]
      occurrence = heading_occurrences[heading_text]
      heading_occurrences[heading_text] += 1
      configured_ids = LEGACY_HEADING_IDS.dig(owner, heading_text)
      legacy_id =
        if configured_ids.is_a?(Array)
          configured_ids[occurrence]
        else
          configured_ids
        end
      id_suffix = legacy_id ? " {#" + legacy_id + "}" : ""
      result << "#{'#' * level} #{heading_text}#{id_suffix}"
      result << ""
      in_table = false
      list_indents.clear
      previous_line_was_list_item = false
      next
    elsif line.match?(/^\s*-{4,}\s*$/)
      append_blank_line(result)
      result << "---"
      result << ""
      in_table = false
      list_indents.clear
      previous_line_was_list_item = false
      next
    elsif line.match?(/^\s*\|\|.*\|\|\s*$/)
      append_blank_line(result) unless in_table
      cells = table_cells(line)
      row = convert_table_line(cells)
      unless in_table
        if table_header_row?(cells)
          result << row
          result << "| #{Array.new(cells.length, '---').join(' | ')} |"
        else
          result << "| #{Array.new(cells.length, '').join(' | ')} |"
          result << "| #{Array.new(cells.length, '---').join(' | ')} |"
          result << row
        end
      end
      result << row if in_table
      in_table = true
      list_indents.clear
      previous_line_was_list_item = false
      next
    end

    append_blank_line(result) if in_table && !line.empty?
    in_table = false

    if (list = line.match(/^(\s+)(\*|\d+\.|[a-z]\.)\s+(.*)$/i))
      source_indent = list[1].length
      if list_indents.empty?
        append_blank_line(result)
        list_indents << source_indent
      elsif source_indent > list_indents.last
        list_indents << source_indent
      elsif source_indent < list_indents.last
        list_indents.pop while list_indents.length > 1 && source_indent < list_indents.last
        list_indents << source_indent if source_indent > list_indents.last
      end

      depth = list_indents.index(source_indent) || list_indents.length - 1
      indent = " " * (depth * 4)
      marker = list[2]
      marker = "1." if marker.match?(/\A[a-z]\.\z/i)
      prefix = "#{indent}#{marker} "
      continuation = " " * prefix.length
      result.concat(
        render_content_with_blocks(
          list[3],
          blocks,
          first_prefix: prefix,
          continuation_prefix: continuation
        )
      )
      previous_line_was_list_item = true
    elsif (definition = line.match(/^\s+(.+?)::\s*(.*)$/))
      append_blank_line(result) unless list_indents.empty?
      list_indents.clear
      result << "**#{definition[1]}**: #{definition[2]}"
      previous_line_was_list_item = false
    else
      if line.empty?
        append_blank_line(result)
      elsif !list_indents.empty? &&
            (indented = line.match(/^(\s+)(.*)$/)) &&
            (parent_depth = list_indents.rindex { |indent| indent < indented[1].length })
        list_indents = list_indents.take(parent_depth + 1)
        append_blank_line(result) if previous_line_was_list_item
        prefix = " " * ((parent_depth + 1) * 4)
        result.concat(
          render_content_with_blocks(
            indented[2],
            blocks,
            first_prefix: prefix,
            continuation_prefix: prefix
          )
        )
      else
        append_blank_line(result) unless list_indents.empty?
        list_indents.clear
        result.concat(render_content_with_blocks(line, blocks))
      end
      previous_line_was_list_item = false
    end
  end

  rendered = result.join("\n")
  raise "Unexpanded MoinMoin block token" if rendered.match?(BLOCK_TOKEN_PATTERN)

  inline.each_with_index { |code, index| rendered.gsub!("@@MOIN_INLINE_#{index}@@") { code } }
  rendered.gsub!(/\n{3,}/, "\n\n")
  rendered.strip + "\n"
end

def attachment_source(owner, filename)
  source_directory = page_directory(owner)
  source = source_directory && File.join(source_directory, "attachments", filename)
  return source if source && File.exist?(source)

  snapshot = File.join(SOURCE_ASSET_ROOT, owner, filename)
  return snapshot if File.exist?(snapshot)

  nil
end

def copy_attachment(source, destination)
  unless NORMALIZED_TEXT_ATTACHMENT_EXTENSIONS.include?(File.extname(source).downcase)
    FileUtils.cp(source, destination)
    return
  end

  text = File.binread(source).gsub("\r\n".b, "\n".b)
  normalized = text.split("\n".b, -1).map do |line|
    line.sub(/[ \t]+\z/n, "")
  end.join("\n".b).sub(/\n*\z/n, "") + "\n".b
  File.write(destination, normalized)
end

def copy_referenced_attachments(qmd_files, course_output)
  references = qmd_files.flat_map do |qmd_file|
    text = File.read(qmd_file, encoding: "UTF-8")
    text.scan(/\]\((?:<([^>]+)>|([^)]+))\)/).filter_map do |angle, plain|
      target = angle || plain
      next unless target.include?("assets/")

      File.expand_path(target, File.dirname(qmd_file))
    end
  end.uniq

  references.each do |destination|
    relative = destination.delete_prefix(File.join(course_output, "assets") + "/")
    owner, filename = relative.split("/", 2)
    source = attachment_source(owner, filename)
    raise "Missing source attachment for #{relative}" unless source

    FileUtils.mkdir_p(File.dirname(destination))
    copy_attachment(source, destination)
  end

  references.length
end

attachment_count = 0

Dir.mktmpdir("migrate-moin-programming-languages") do |temporary_root|
  temporary_output_root = File.join(temporary_root, "old")
  temporary_course_output = File.join(temporary_output_root, COURSE_NAME)
  FileUtils.mkdir_p(temporary_course_output)

  course_body = convert_moin(
    COURSE_SOURCE,
    owner: COURSE_NAME,
    context: :course
  )
  course_page = [
    qmd_front_matter(
      COURSE_TITLE,
      number_sections: COURSE_SOURCE.match?(SECTION_NUMBER_PRAGMA_PATTERN)
    ),
    "[返回旧版首页](首页.qmd)",
    "",
    course_body
  ].join("\n")
  temporary_course_page = File.join(temporary_output_root, "#{COURSE_NAME}.qmd")
  File.write(temporary_course_page, course_page)

  PRIMARY_PAGES.each do |page_name|
    source = page_source(page_name)
    placeholder =
      if !page_has_readable_revision?(page_name)
        <<~MARKDOWN
          ::: {.callout-warning}
          '''源页面不可用'''

          MoinMoin 备份中保留了这个页面名，但没有可读取的当前版本。
          :::
        MARKDOWN
      elsif source.strip.empty?
        "::: {.callout-note}\n原 MoinMoin 页面暂无正文内容。\n:::\n"
      elsif (redirect = source.match(/\A#redirect\s+(.+?)\s*\z/))
        target = redirect[1]
        "::: {.callout-note}\n原页面重定向至“#{target}”，该目标尚未迁移。\n:::\n"
      else
        source
      end
    if page_uses_fallback_revision?(page_name)
      placeholder = [
        "::: {.callout-warning}",
        "'''已恢复历史版本'''",
        "",
        "当前版本 #{page_current_revision(page_name)} 在备份中缺失；以下内容来自最新可读取版本 #{page_revision(page_name)}。",
        ":::",
        "",
        placeholder
      ].join("\n")
    end
    body = convert_moin(
      placeholder,
      owner: page_name,
      context: :child,
      expand_includes: page_name == "Python介绍"
    )
    page = [
      qmd_front_matter(
        page_output_name(page_name),
        number_sections: source.match?(SECTION_NUMBER_PRAGMA_PATTERN)
      ),
      "[返回“#{COURSE_TITLE}”](<#{page_link(COURSE_NAME, page_name, :child)}>)",
      "",
      body
    ].join("\n")
    page_path = File.join(
      temporary_course_output,
      "#{page_output_name(page_name)}.qmd"
    )
    FileUtils.mkdir_p(File.dirname(page_path))
    File.write(page_path, page)
  end

  qmd_files = [temporary_course_page] +
              Dir.glob(File.join(temporary_course_output, "**", "*.qmd"))
  attachment_count = copy_referenced_attachments(qmd_files, temporary_course_output)

  FileUtils.rm_rf(COURSE_OUTPUT)
  FileUtils.mv(temporary_course_output, COURSE_OUTPUT)
  FileUtils.cp(temporary_course_page, File.join(OUTPUT_ROOT, "#{COURSE_NAME}.qmd"))
end

puts "Converted #{MIGRATED_PAGES.length} pages"
puts "Copied #{attachment_count} attachments"
