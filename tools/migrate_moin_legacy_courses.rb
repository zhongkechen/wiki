# frozen_string_literal: true

require "cgi"
require "fileutils"
require "json"
require "tmpdir"

REPOSITORY_ROOT = File.expand_path("..", __dir__)
DEFAULT_SOURCE_ROOT = File.join(REPOSITORY_ROOT, "mywiki", "data", "pages")
SOURCE_ROOT = File.expand_path(ENV.fetch("MOIN_SOURCE_ROOT", DEFAULT_SOURCE_ROOT))
OUTPUT_ROOT = File.join(REPOSITORY_ROOT, "old")
SOURCE_SNAPSHOT_PATH = File.join(
  __dir__,
  "data",
  "moin_legacy_course_sources.json"
)
COURSE_NAMES = %w[
  计算机科学导论
  离散数学
  计算机图形学
  算法与数据结构
].freeze
INTRODUCTION_COURSE = "计算机科学导论"
INTRODUCTION_CHILD_INDEXES = %w[计算机导论习题库].freeze
IMAGE_EXTENSIONS = %w[.bmp .gif .jpeg .jpg .png .svg .tif .tiff .webp].freeze
BLOCK_TOKEN_PATTERN = /@@MOIN_BLOCK_(\d+)@@/

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

SOURCE_SNAPSHOT =
  if File.exist?(SOURCE_SNAPSHOT_PATH)
    JSON.parse(File.read(SOURCE_SNAPSHOT_PATH, encoding: "UTF-8"))
  else
    {}
  end
AVAILABLE_PAGE_NAMES = (PAGE_INDEX.keys + SOURCE_SNAPSHOT.keys).uniq.freeze
SHARED_PAGE_LINKS = {
  "Python语言的基本概念" =>
    "Python游戏开发基础/Python语言的基本概念.qmd"
}.freeze

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
  return nil unless File.file?(current_path)

  File.read(current_path).strip
end

def page_revision(name)
  directory = page_directory(name)
  return snapshot_record(name)["revision"] unless directory

  revisions_directory = File.join(directory, "revisions")
  return nil unless Dir.exist?(revisions_directory)

  current_revision = page_current_revision(name)
  current_path =
    current_revision && File.join(revisions_directory, current_revision)
  return current_revision if current_path && File.file?(current_path)

  Dir.children(revisions_directory).select do |revision|
    File.file?(File.join(revisions_directory, revision))
  end.max
end

def page_source(name)
  directory = page_directory(name)
  return snapshot_record(name).fetch("source", "") unless directory

  revision = page_revision(name)
  return "" unless revision

  File.read(
    File.join(directory, "revisions", revision),
    encoding: "UTF-8",
    invalid: :replace
  )
end

def linked_page_names(source)
  source.scan(/\[\[([^\]]+)\]\]/).flatten.filter_map do |raw|
    target = raw.split("|", 2).first.strip
    next if target.start_with?("attachment:")
    next if target.match?(%r{\A(?:https?|ftp|mailto):})
    next if target.start_with?("#")

    target.sub(/\A\^/, "")
  end.uniq
end

def matching_page_names(pattern)
  expression = pattern.sub(/\Aregex:/, "")
  matcher =
    begin
      Regexp.new(expression)
    rescue RegexpError
      /#{Regexp.escape(expression)}/
    end
  AVAILABLE_PAGE_NAMES.select { |page_name| page_name.match?(matcher) }.sort
end

def page_list_page_names(source)
  source.scan(/<<PageList\(([^)]+)\)>>/).flatten.flat_map do |pattern|
    matching_page_names(pattern)
  end.uniq.sort
end

INTRODUCTION_PRIMARY_PAGES =
  linked_page_names(page_source(INTRODUCTION_COURSE)).freeze
INTRODUCTION_INDEX_PAGES = INTRODUCTION_CHILD_INDEXES.flat_map do |page_name|
  linked_page_names(page_source(page_name))
end.freeze
INTRODUCTION_SEED_PAGES = (
  INTRODUCTION_PRIMARY_PAGES + INTRODUCTION_INDEX_PAGES
).uniq.freeze
INTRODUCTION_SECONDARY_PAGES = INTRODUCTION_SEED_PAGES.flat_map do |page_name|
  linked_page_names(page_source(page_name))
end.uniq.freeze
INTRODUCTION_PAGE_LIST_PAGES = (
  [INTRODUCTION_COURSE] +
  INTRODUCTION_SEED_PAGES +
  INTRODUCTION_SECONDARY_PAGES
).flat_map do |page_name|
  page_list_page_names(page_source(page_name))
end.uniq.freeze
INTRODUCTION_PAGES = (
  [INTRODUCTION_COURSE] +
  INTRODUCTION_SEED_PAGES +
  INTRODUCTION_SECONDARY_PAGES +
  INTRODUCTION_PAGE_LIST_PAGES.reject do |page_name|
    SHARED_PAGE_LINKS.key?(page_name)
  end
).uniq.freeze
COURSE_PAGES = {
  INTRODUCTION_COURSE => INTRODUCTION_PAGES,
  "离散数学" => ["离散数学"],
  "计算机图形学" => ["计算机图形学"],
  "算法与数据结构" => ["算法与数据结构"]
}.freeze
MIGRATED_PAGE_NAMES = COURSE_PAGES.values.flatten.uniq.freeze
SOURCE_PAGE_NAMES = (
  MIGRATED_PAGE_NAMES + SHARED_PAGE_LINKS.keys
).uniq.freeze

missing_courses = COURSE_NAMES.reject do |name|
  PAGE_INDEX.key?(name) || SOURCE_SNAPSHOT.key?(name)
end
raise "Missing course source pages: #{missing_courses.join(', ')}" unless missing_courses.empty?

if PAGE_INDEX.any?
  snapshot = SOURCE_PAGE_NAMES.to_h do |name|
    [
      name,
      {
        "source" => page_source(name),
        "revision" => page_revision(name),
        "current_revision" => page_current_revision(name)
      }
    ]
  end
  FileUtils.mkdir_p(File.dirname(SOURCE_SNAPSHOT_PATH))
  File.write(SOURCE_SNAPSHOT_PATH, JSON.pretty_generate(snapshot) + "\n")
end

def qmd_front_matter(title)
  escaped = title.gsub("\\", "\\\\").gsub('"', '\\"')
  <<~YAML
    ---
    title: "#{escaped}"
    lang: zh
    toc: true
    format:
      html:
        code-copy: true
        html-math-method: mathjax
    ---
  YAML
end

def normalize_source(page_name, source)
  normalized = source

  case page_name
  when "计算机导论实验大纲"
    normalized = normalized.gsub(
      "|| 数据库基础入门||| 2||",
      "|| 数据库基础入门|| 2||"
    )
  when "离散数学"
    normalized = normalized.gsub(
      /\[\[attachment:离散数学教学计划进度表\.doc\s*\]\]/,
      "离散数学教学计划进度表.doc（原附件缺失）"
    )
  when "计算机图形学"
    replacements = {
      "attachment:05.ppt|第06部分  消隐" =>
        "attachment:06.ppt|第06部分  消隐",
      "attachment:05.ppt|第09部分  OpenGL1" =>
        "attachment:091.ppt|第09部分  OpenGL1",
      "attachment:05.ppt|第09部分  OpenGL2" =>
        "attachment:092.ppt|第09部分  OpenGL2",
      "attachment:05.ppt|第09部分  OpenGL3" =>
        "attachment:093.ppt|第09部分  OpenGL3",
      "attachment:03.doc|实验报告4" => "attachment:04.doc|实验报告4",
      "attachment:04.doc|实验报告6" => "attachment:06.doc|实验报告6",
      "attachment:05.doc|实验报告11" => "attachment:11.doc|实验报告11",
      "attachment:05.doc|实验报告13" => "attachment:13.doc|实验报告13",
      "attachment:07.doc|实验报告15" => "attachment:15.doc|实验报告15",
      "attachment:05.doc|上机实验指导" => "attachment:36.doc|上机实验指导",
      "attachment:zuoyejieda.doc|作业解答" =>
        "attachment:zuoyejieda.ppt|作业解答"
    }
    replacements.each { |before, after| normalized = normalized.gsub(before, after) }
  when "算法与数据结构"
    normalized = normalized.gsub(
      "attachment:DSKC05.doc|算法与数据结构实验运行表",
      "attachment:DSKC05.xls|算法与数据结构实验运行表"
    )
  end

  normalized
end

def page_link(target, course_name, context)
  clean_target = target.sub(/\A\^/, "")
  course_pages = COURSE_PAGES.fetch(course_name)

  if clean_target == course_name
    context == :course ? "#{course_name}.qmd" : "../#{course_name}.qmd"
  elsif course_pages.include?(clean_target)
    context == :course ? "#{course_name}/#{clean_target}.qmd" : "#{clean_target}.qmd"
  elsif (shared_path = SHARED_PAGE_LINKS[clean_target])
    context == :course ? shared_path : "../#{shared_path}"
  else
    nil
  end
end

def safe_attachment_name(filename)
  clean = filename.strip.sub(%r{\A\./}, "")
  raise "Unsafe attachment path: #{filename}" if clean.split("/").include?("..")

  clean
end

def asset_target(owner, filename, course_name, context)
  clean_filename = safe_attachment_name(filename)
  relative = "assets/#{owner}/#{clean_filename}"
  context == :course ? "#{course_name}/#{relative}" : relative
end

def markdown_target(path)
  "<#{path}>"
end

def convert_link(raw, owner, course_name, context)
  target, label = raw.split("|", 2)
  target = target.strip
  label = label&.strip
  label = target if label.nil? || label.empty?

  if target.start_with?("attachment:")
    filename = target.delete_prefix("attachment:")
    visible = label.start_with?("attachment:") ? File.basename(filename) : label
    path = asset_target(owner, filename, course_name, context)
    return "[#{visible}](#{markdown_target(path)})"
  end

  return "[#{label}](#{target})" if target.match?(%r{\A(?:https?|ftp|mailto):})
  return "[#{label}](#{target})" if target.start_with?("#")

  path = page_link(target, course_name, context)
  path ? "[#{label}](#{markdown_target(path)})" : label
end

def normalize_latex(content)
  formula = content.lines.map(&:rstrip).join("\n").strip
  if formula.start_with?("$$") && formula.end_with?("$$")
    formula = formula.delete_prefix("$$").delete_suffix("$$").strip
  elsif formula.start_with?("$") && formula.end_with?("$")
    formula = formula.delete_prefix("$").delete_suffix("$").strip
  end
  formula
end

def markdown_code_span(content)
  code = content.strip
  delimiter = "`" * ((code.scan(/`+/).map(&:length).max || 0) + 1)
  padding = code.start_with?("`") || code.end_with?("`") ? " " : ""
  "#{delimiter}#{padding}#{code}#{padding}#{delimiter}"
end

def convert_blocks(text)
  blocks = []
  converted = text.gsub(/\{\{\{(?:#!([^\n]+))?\s*\n(.*?)\}\}\}/m) do
    language = Regexp.last_match(1)&.strip
    body = Regexp.last_match(2).lines.map(&:rstrip).join("\n").rstrip
    rendered =
      if language == "latex"
        "$$\n#{normalize_latex(body)}\n$$"
      else
        fence_language = language.to_s.gsub(/\s.*\z/, "")
        "```#{fence_language}\n#{body}\n```"
      end
    token = "@@MOIN_BLOCK_#{blocks.length}@@"
    blocks << rendered
    token
  end

  inline = []
  converted.gsub!(/\{\{\{([^\n]*?)\}\}\}/) do
    token = "@@MOIN_INLINE_#{inline.length}@@"
    inline << markdown_code_span(Regexp.last_match(1))
    token
  end

  [converted, blocks, inline]
end

def protect_nowiki(text)
  fragments = []
  converted = text.gsub(%r{<nowiki>(.*?)</nowiki>}mi) do
    token = "@@MOIN_NOWIKI_#{fragments.length}@@"
    fragments << CGI.escapeHTML(Regexp.last_match(1))
    token
  end
  [converted, fragments]
end

def add_latex_blocks(source, blocks)
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

def image_markup(filename, owner, course_name, context)
  clean_filename = safe_attachment_name(filename)
  path = asset_target(owner, clean_filename, course_name, context)
  if IMAGE_EXTENSIONS.include?(File.extname(clean_filename).downcase)
    "![#{File.basename(clean_filename)}](#{markdown_target(path)})"
  else
    "[#{File.basename(clean_filename)}](#{markdown_target(path)})"
  end
end

def external_image_markup(url, label)
  visible = label.to_s.empty? ? File.basename(url.split(/[?#]/, 2).first) : label
  "![#{visible}](#{url})"
end

def render_content_with_blocks(content, blocks, first_prefix: "", continuation_prefix: "")
  parts = content.split(BLOCK_TOKEN_PATTERN, -1)
  lines = []
  current = first_prefix.dup

  parts.each_with_index do |part, index|
    if index.even?
      current << part unless part.empty?
      next
    end

    block = blocks.fetch(part.to_i)
    lines << current.rstrip unless current.strip.empty?
    lines << "" unless lines.empty? || lines.last.empty?
    block.each_line do |block_line|
      lines << "#{continuation_prefix}#{block_line.rstrip}"
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
  escaped = cells.map { |cell| cell.gsub("|", "\\|") }
  "| #{escaped.join(' | ')} |"
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

def render_page_list(pattern)
  matching_page_names(pattern).map do |page_name|
    " * [[#{page_name}]]"
  end.join("\n")
end

def list_item_match(line)
  line.match(/^(\s+)(\*|\d+\.|[a-z]\.)\s+(.*)$/i) ||
    line.match(/^(\s+)(\d+、)\s*(.*)$/)
end

def convert_moin(text, owner:, course_name:, context:)
  source = normalize_source(owner, text).gsub("\r\n", "\n")
  source.gsub!(/<<PageList\(([^)]+)\)>>/) do
    render_page_list(Regexp.last_match(1))
  end
  source, nowiki = protect_nowiki(source)
  source.gsub!(%r{</?center>}i, "")
  source.gsub!(%r{<br\s*/?>}i, "<<BR>>")
  source, blocks, inline = convert_blocks(source)
  source = add_latex_blocks(source, blocks)
  source = escape_plain_moin_markup(source)
  source.gsub!(/\{\{attachment:([^}\n]+)\}\}/) do
    image_markup(Regexp.last_match(1), owner, course_name, context)
  end
  source.gsub!(/\{\{(https?:\/\/[^}|\n]+)(?:\|([^}|\n]*))?(?:\|[^}\n]*)?\}\}/) do
    external_image_markup(Regexp.last_match(1), Regexp.last_match(2))
  end
  source.gsub!(/\[\[([^\]]+)\]\]/) do
    convert_link(Regexp.last_match(1), owner, course_name, context)
  end
  source.gsub!("<<BR>>", "<br>")
  source.gsub!(/<<(?:TableOfContents|Navigation\([^)]*\))>>/, "")
  source.gsub!(/<<Anchor\(([^)]+)\)>>/, '<a id="\1"></a>')
  source.gsub!(/<<FootNote\(([^)]+)\)>>/, '^[\1]')
  source.gsub!(/<<[^>]+>>/, "")
  source.gsub!(/'''(.*?)'''/m, '**\1**')
  source.gsub!(/''(.*?)''/m, '*\1*')

  result = []
  in_table = false
  list_indents = []

  source.each_line do |raw_line|
    line = raw_line.rstrip

    if line.match?(/\A\s*Category\S+(?:\s+Category\S+)*\s*\z/)
      next
    elsif line.start_with?("##", "#acl", "#format")
      next
    elsif (heading = line.match(/^\s*(=+)\s*(.*?)\s*\1\s*$/))
      append_blank_line(result)
      level = [heading[1].length, 2].max
      result << "#{'#' * level} #{heading[2]}"
      result << ""
      in_table = false
      list_indents.clear
      next
    elsif line.match?(/^\s*\|\|.*\|\|\s*$/)
      append_blank_line(result) unless in_table
      cells = table_cells(line)
      result << convert_table_line(cells)
      unless in_table
        cell_count = cells.length
        result << "| #{Array.new(cell_count, '---').join(' | ')} |"
      end
      in_table = true
      list_indents.clear
      next
    end

    append_blank_line(result) if in_table && !line.empty?
    in_table = false

    if (list = list_item_match(line))
      source_indent = list[1].length
      if list_indents.empty?
        append_blank_line(result)
        list_indents << source_indent
      elsif source_indent > list_indents.last
        list_indents << source_indent
      elsif source_indent < list_indents.last
        list_indents.pop while list_indents.length > 1 &&
                               source_indent < list_indents.last
        list_indents << source_indent if source_indent > list_indents.last
      end

      depth = list_indents.index(source_indent) || list_indents.length - 1
      indent = " " * (depth * 4)
      marker =
        list[2].match?(/[a-z]\./i) || list[2].end_with?("、") ? "1." : list[2]
      prefix = "#{indent}#{marker} "
      result.concat(
        render_content_with_blocks(
          list[3],
          blocks,
          first_prefix: prefix,
          continuation_prefix: " " * prefix.length
        )
      )
    elsif (definition = line.match(/^\s+(.+?)::\s*(.*)$/))
      append_blank_line(result) unless list_indents.empty?
      list_indents.clear
      result << "**#{definition[1]}**: #{definition[2]}"
    elsif line.empty?
      append_blank_line(result)
      list_indents.clear
    else
      append_blank_line(result) unless list_indents.empty?
      list_indents.clear
      result.concat(render_content_with_blocks(line, blocks))
    end
  end

  rendered = result.join("\n")
  raise "Unexpanded MoinMoin block token" if rendered.match?(BLOCK_TOKEN_PATTERN)

  inline.each_with_index do |code, index|
    rendered.gsub!("@@MOIN_INLINE_#{index}@@") { code }
  end
  nowiki.each_with_index do |content, index|
    rendered.gsub!("@@MOIN_NOWIKI_#{index}@@") { content }
  end
  rendered.gsub!(/\n{3,}/, "\n\n")
  rendered.strip + "\n"
end

def attachment_source(course_name, owner, filename)
  source_directory = page_directory(owner)
  source =
    source_directory &&
    File.join(source_directory, "attachments", filename)
  return source if source && File.file?(source)

  existing = File.join(
    OUTPUT_ROOT,
    course_name,
    "assets",
    owner,
    filename
  )
  return existing if File.file?(existing)

  nil
end

def referenced_attachments(qmd_files, course_output)
  qmd_files.flat_map do |qmd_file|
    text = File.read(qmd_file, encoding: "UTF-8")
    text.scan(/\]\((?:<([^>]+)>|([^)]+))\)/).filter_map do |angle, plain|
      target = angle || plain
      next unless target.include?("assets/")

      destination = File.expand_path(target, File.dirname(qmd_file))
      next unless destination.start_with?("#{course_output}/")

      relative = destination.delete_prefix("#{course_output}/assets/")
      owner, filename = relative.split("/", 2)
      [owner, filename] if owner && filename
    end
  end.uniq
end

total_pages = 0
total_attachments = 0

Dir.mktmpdir("migrate-moin-legacy-courses") do |temporary_root|
  temporary_output_root = File.join(temporary_root, "old")
  FileUtils.mkdir_p(temporary_output_root)

  COURSE_PAGES.each do |course_name, page_names|
    temporary_course_output = File.join(temporary_output_root, course_name)
    FileUtils.mkdir_p(temporary_course_output)

    source = page_source(course_name)
    body = convert_moin(
      source,
      owner: course_name,
      course_name: course_name,
      context: :course
    )
    course_page = [
      qmd_front_matter(course_name),
      "[返回旧版首页](首页.qmd)",
      "",
      body
    ].join("\n")
    temporary_course_page =
      File.join(temporary_output_root, "#{course_name}.qmd")
    File.write(temporary_course_page, course_page)

    page_names.drop(1).each do |page_name|
      child_source = page_source(page_name)
      child_source =
        "::: {.callout-note}\n该页面在旧 Wiki 中暂时没有正文。\n:::\n" if child_source.strip.empty?
      child_body = convert_moin(
        child_source,
        owner: page_name,
        course_name: course_name,
        context: :child
      )
      child_page = [
        qmd_front_matter(page_name),
        "[返回“#{course_name}”](../#{course_name}.qmd)",
        "",
        child_body
      ].join("\n")
      File.write(
        File.join(temporary_course_output, "#{page_name}.qmd"),
        child_page
      )
    end

    qmd_files = [
      temporary_course_page,
      *Dir.glob(File.join(temporary_course_output, "**", "*.qmd"))
    ]
    referenced_attachments(
      qmd_files,
      temporary_course_output
    ).each do |owner, filename|
      source_path = attachment_source(course_name, owner, filename)
      raise "Missing source attachment for #{owner}/#{filename}" unless source_path

      destination = File.join(
        temporary_course_output,
        "assets",
        owner,
        filename
      )
      FileUtils.mkdir_p(File.dirname(destination))
      FileUtils.cp(source_path, destination)
      total_attachments += 1
    end

    FileUtils.rm_rf(File.join(OUTPUT_ROOT, course_name))
    FileUtils.mv(temporary_course_output, File.join(OUTPUT_ROOT, course_name))
    FileUtils.cp(
      temporary_course_page,
      File.join(OUTPUT_ROOT, "#{course_name}.qmd")
    )
    total_pages += page_names.length
  end
end

puts "Converted #{total_pages} pages"
puts "Copied #{total_attachments} attachments"
