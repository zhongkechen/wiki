# frozen_string_literal: true

require "fileutils"

SOURCE_ROOT = File.expand_path("../mywiki/data/pages", __dir__)
OUTPUT_ROOT = File.expand_path("../old", __dir__)
COURSE_NAME = "数字图像处理"
COURSE_OUTPUT = File.join(OUTPUT_ROOT, COURSE_NAME)

IMAGE_EXTENSIONS = %w[.bmp .gif .jpeg .jpg .png .svg .tif .tiff .webp].freeze

def decode_page_name(entry)
  entry.gsub(/\(([0-9a-fA-F]+)\)/) do
    [$1].pack("H*").force_encoding("UTF-8")
  end
end

PAGE_INDEX = Dir.children(SOURCE_ROOT).to_h do |entry|
  [decode_page_name(entry), entry]
end

def page_directory(name)
  entry = PAGE_INDEX[name]
  entry && File.join(SOURCE_ROOT, entry)
end

def page_source(name)
  directory = page_directory(name)
  return "" unless directory

  current_path = File.join(directory, "current")
  return "" unless File.exist?(current_path)

  revision = File.read(current_path).strip
  revision_path = File.join(directory, "revisions", revision)
  return "" unless File.exist?(revision_path)

  File.read(revision_path, encoding: "UTF-8", invalid: :replace)
end

def direct_child_names(course_source)
  course_source.scan(/\[\[([^\]]+)\]\]/).flatten.filter_map do |raw|
    next if raw.start_with?("attachment:") || raw.match?(%r{\Ahttps?://})

    raw.split("|", 2).first
  end.uniq
end

COURSE_SOURCE = page_source(COURSE_NAME)
DIRECT_CHILDREN = direct_child_names(COURSE_SOURCE).freeze
MIGRATED_PAGES = ([COURSE_NAME] + DIRECT_CHILDREN).freeze

def qmd_front_matter(title)
  escaped = title.gsub("\\", "\\\\").gsub('"', '\\"')
  <<~YAML
    ---
    title: "#{escaped}"
    ---
  YAML
end

def output_context(page_name)
  page_name == COURSE_NAME ? :course : :child
end

def page_link(target, context)
  clean_target = target.sub(/\A\^/, "")

  if DIRECT_CHILDREN.include?(clean_target)
    context == :course ? "#{COURSE_NAME}/#{clean_target}.qmd" : "#{clean_target}.qmd"
  elsif clean_target == COURSE_NAME
    context == :course ? "#{COURSE_NAME}.qmd" : "../#{COURSE_NAME}.qmd"
  else
    context == :course ? "#{clean_target}.html" : "../#{clean_target}.html"
  end
end

def asset_target(owner, filename, context)
  clean_filename = filename.sub(%r{\A\.\./}, "")
  parts = clean_filename.split("/", 2)

  if parts.length == 2 && MIGRATED_PAGES.include?(parts.first)
    owner = parts.first
    clean_filename = parts.last
  end

  relative = "assets/#{owner}/#{clean_filename}"
  context == :course ? "#{COURSE_NAME}/#{relative}" : relative
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
  label ||= target

  if target.start_with?("attachment:")
    spec = target.delete_prefix("attachment:")
    visible = label.start_with?("attachment:") ? File.basename(spec) : label
    path = asset_target(owner, spec, context)
    return "[#{visible}](#{markdown_target(path)})"
  end

  return "[#{label}](#{target})" if target.match?(%r{\A(?:https?|ftp|mailto):})
  return "[#{label}](#{target})" if target.start_with?("#")

  "[#{label}](#{markdown_target(page_link(target, context))})"
end

def normalize_latex(content)
  formula = content.lines.map(&:rstrip).join("\n").strip
  formula = formula.delete_prefix("$$").delete_suffix("$$").strip if formula.start_with?("$$") && formula.end_with?("$$")
  formula = formula.delete_prefix("$").delete_suffix("$").strip if formula.start_with?("$") && formula.end_with?("$")
  formula
end

def markdown_code_span(content)
  code = content.strip
  longest_run = code.scan(/`+/).map(&:length).max || 0
  delimiter = "`" * (longest_run + 1)
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
    "\n\n#{token}\n\n"
  end

  inline = []
  converted.gsub!(/\{\{\{([^\n]*?)\}\}\}/) do
    token = "@@MOIN_INLINE_#{inline.length}@@"
    inline << markdown_code_span(Regexp.last_match(1))
    token
  end

  [converted, blocks, inline]
end

def convert_table_line(line)
  body = line.strip.delete_prefix("||").delete_suffix("||")
  cells = body.split("||").map do |cell|
    cell.strip.sub(/\A(?:<[^>]+>\s*)+/, "")
  end
  "| #{cells.join(' | ')} |"
end

def convert_moin(text, owner:, context:, expand_includes: false)
  source = text.gsub("\r\n", "\n")

  if expand_includes
    source.gsub!(/<<Include\(\^?([^)]+)\)>>/) do
      included_name = Regexp.last_match(1)
      page_source(included_name)
    end
  end

  source, blocks, inline = convert_blocks(source)

  source.gsub!(/<<latex\((.*?)\)>>/m) do
    formula = Regexp.last_match(1).strip
    display = formula.start_with?("$$") && formula.end_with?("$$")
    normalized = normalize_latex(formula)
    display ? "\n\n$$\n#{normalized}\n$$\n\n" : "$#{normalized}$"
  end

  source.gsub!(/\{\{attachment:([^}\n]+)\}\}/) do
    attachment_markup(Regexp.last_match(1), owner, context, image: true)
  end

  source.gsub!(/\[\[([^\]]+)\]\]/) do
    convert_link(Regexp.last_match(1), owner, context)
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

  source.each_line do |raw_line|
    line = raw_line.rstrip

    if line.start_with?("##")
      next
    elsif (heading = line.match(/^\s*(=+)\s*(.*?)\s*\1\s*$/))
      level = [heading[1].length, 2].max
      result << "#{'#' * level} #{heading[2]}"
      in_table = false
      next
    elsif line.match?(/^\s*\|\|.*\|\|\s*$/)
      result << convert_table_line(line)
      unless in_table
        cell_count = line.scan(/\|\|/).length - 1
        result << "| #{Array.new(cell_count, '---').join(' | ')} |"
      end
      in_table = true
      next
    end

    in_table = false

    if (list = line.match(/^(\s+)(\*|1\.|[a-z]\.)\s+(.*)$/i))
      indent = " " * [list[1].length - 1, 0].max
      marker = list[2].match?(/[a-z]\./i) ? "1." : list[2]
      result << "#{indent}#{marker} #{list[3]}"
    elsif (definition = line.match(/^\s+(.+?)::\s*(.*)$/))
      result << "**#{definition[1]}**: #{definition[2]}"
    else
      result << line
    end
  end

  rendered = result.join("\n")
  blocks.each_with_index { |block, index| rendered.gsub!("@@MOIN_BLOCK_#{index}@@") { block } }
  inline.each_with_index { |code, index| rendered.gsub!("@@MOIN_INLINE_#{index}@@") { code } }
  rendered.gsub!(/\n{3,}/, "\n\n")
  rendered.strip + "\n"
end

def copy_referenced_attachments(qmd_files)
  references = qmd_files.flat_map do |qmd_file|
    text = File.read(qmd_file, encoding: "UTF-8")
    text.scan(/\]\((?:<([^>]+)>|([^)]+))\)/).filter_map do |angle, plain|
      target = angle || plain
      next unless target.include?("assets/")

      File.expand_path(target, File.dirname(qmd_file))
    end
  end.uniq

  references.each do |destination|
    relative = destination.delete_prefix(File.join(COURSE_OUTPUT, "assets") + "/")
    owner, filename = relative.split("/", 2)
    source_directory = page_directory(owner)
    source = source_directory && File.join(source_directory, "attachments", filename)
    raise "Missing source attachment for #{relative}" unless source && File.exist?(source)

    FileUtils.mkdir_p(File.dirname(destination))
    FileUtils.cp(source, destination)
  end

  references.length
end

FileUtils.rm_rf(COURSE_OUTPUT)
FileUtils.mkdir_p(COURSE_OUTPUT)

course_body = convert_moin(COURSE_SOURCE, owner: COURSE_NAME, context: :course)
course_page = [
  qmd_front_matter(COURSE_NAME),
  "[返回首页](首页.qmd)",
  "",
  course_body
].join("\n")
File.write(File.join(OUTPUT_ROOT, "#{COURSE_NAME}.qmd"), course_page)

DIRECT_CHILDREN.each do |page_name|
  source = page_source(page_name)
  placeholder = source.strip.empty? ? "::: {.callout-note}\n该页面在旧 Wiki 中暂时没有正文。\n:::\n" : source
  body = convert_moin(
    placeholder,
    owner: page_name,
    context: :child,
    expand_includes: page_name == "图像的数学形态学处理"
  )
  page = [
    qmd_front_matter(page_name),
    "[返回“数字图像处理”](../数字图像处理.qmd)",
    "",
    body
  ].join("\n")
  File.write(File.join(COURSE_OUTPUT, "#{page_name}.qmd"), page)
end

qmd_files = [File.join(OUTPUT_ROOT, "#{COURSE_NAME}.qmd")] +
            Dir.glob(File.join(COURSE_OUTPUT, "*.qmd"))
attachment_count = copy_referenced_attachments(qmd_files)

puts "Converted #{MIGRATED_PAGES.length} pages"
puts "Copied #{attachment_count} attachments"
