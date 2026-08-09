# frozen_string_literal: true

require "fileutils"
require "json"
require "tmpdir"

DEFAULT_SOURCE_ROOT = File.expand_path("../mywiki/data/pages", __dir__)
SOURCE_ROOT = File.expand_path(ENV.fetch("MOIN_SOURCE_ROOT", DEFAULT_SOURCE_ROOT))
OUTPUT_ROOT = File.expand_path("../old", __dir__)
COURSE_NAME = "Linux"
COURSE_OUTPUT = File.join(OUTPUT_ROOT, COURSE_NAME)
SOURCE_SNAPSHOT_PATH = File.expand_path("data/moin_linux_sources.json", __dir__)
SOURCE_ASSET_ROOT = File.expand_path("data/moin_linux_assets", __dir__)
SOURCE_SNAPSHOT =
  if File.exist?(SOURCE_SNAPSHOT_PATH)
    JSON.parse(File.read(SOURCE_SNAPSHOT_PATH, encoding: "UTF-8"))
  else
    {}
  end

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

def linked_page_names(source)
  source.scan(/\[\[([^\]]+)\]\]/).flatten.filter_map do |raw|
    next if raw.start_with?("attachment:") || raw.match?(%r{\Ahttps?://})

    raw.split("|", 2).first
  end.uniq
end

def included_page_names(source)
  source.scan(/<<Include\(\^?([^,)]+)(?:,[^)]*)?\)>>/).flatten.uniq
end

COURSE_SOURCE = page_source(COURSE_NAME)
direct_pages = linked_page_names(COURSE_SOURCE)
primary_pages = direct_pages.dup
queue = direct_pages.select { |page_name| page_has_readable_revision?(page_name) }

until queue.empty?
  page_name = queue.shift
  source = page_source(page_name)
  descendants = linked_page_names(source).select { |target| target.start_with?("Linux") }
  descendants.concat(included_page_names(source))

  descendants.each do |target|
    next if target == COURSE_NAME || primary_pages.include?(target)
    next unless page_has_readable_revision?(target)

    primary_pages << target
    queue << target
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

  Dir.mktmpdir("moin-linux-assets") do |temporary_root|
    temporary_asset_root = File.join(temporary_root, "moin_linux_assets")
    FileUtils.mkdir_p(temporary_asset_root)

    SOURCE_PAGE_NAMES.each do |page_name|
      directory = page_directory(page_name)
      attachments = directory && File.join(directory, "attachments")
      next unless attachments && Dir.exist?(attachments)

      destination = File.join(temporary_asset_root, page_name)
      FileUtils.mkdir_p(destination)
      Dir.children(attachments).each do |filename|
        source = File.join(attachments, filename)
        FileUtils.cp(source, destination) if File.file?(source)
      end
    end

    FileUtils.rm_rf(SOURCE_ASSET_ROOT)
    FileUtils.mv(temporary_asset_root, SOURCE_ASSET_ROOT)
  end
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

def page_link(target, context)
  clean_target = target.sub(/\A\^/, "")

  if clean_target == COURSE_NAME
    context == :course ? "#{COURSE_NAME}.qmd" : "../#{COURSE_NAME}.qmd"
  elsif MIGRATED_PAGES.include?(clean_target)
    context == :course ? "#{COURSE_NAME}/#{clean_target}.qmd" : "#{clean_target}.qmd"
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
      elsif language == "html"
        body.sub(/\A<html>\s*<body>/i, "").sub(%r{</body>\s*</html>\z}i, "")
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
  return source if source.include?("<<AttachList>>") || source.include?("attachment:")

  [source.rstrip, "", "= 附件 =", render_attach_list(owner), ""].join("\n")
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

def convert_table_line(line)
  body = line.strip.delete_prefix("||").delete_suffix("||")
  cells = body.split("||").map do |cell|
    cell.strip.sub(/\A(?:<[^>]+>\s*)+/, "")
  end
  "| #{cells.join(' | ')} |"
end

def convert_moin(text, owner:, context:, expand_includes: false)
  source = text.gsub("\r\n", "\n")
  source = include_unlisted_attachments(source, owner)

  source.gsub!(/<<Include\(\^?([^,)]+)(?:,[^)]*)?\)>>/) do
    included_name = Regexp.last_match(1)
    if expand_includes
      page_source(included_name)
    else
      "[[#{included_name}|#{included_name}]]"
    end
  end

  source, blocks, inline = convert_blocks(source)
  source = add_display_math_block(source, blocks)
  source.gsub!("<<AttachList>>", render_attach_list(owner))

  source.gsub!(/\{\{attachment:([^}\n]+)\}\}/) do
    attachment_markup(Regexp.last_match(1), owner, context, image: true)
  end

  source.gsub!(/\{\{(https?:\/\/[^}|\n]+)(?:\|([^}|\n]*))?(?:\|[^}\n]*)?\}\}/) do
    external_image_markup(Regexp.last_match(1), Regexp.last_match(2))
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

  source.gsub!(/'''(.*?)'''/m, '**\1**')
  source.gsub!(/''(.*?)''/m, '*\1*')

  result = []
  in_table = false
  list_indents = []
  previous_line_was_list_item = false

  source.each_line do |raw_line|
    line = raw_line.rstrip

    if line.match?(/\A\s*Category\S+(?:\s+Category\S+)*\s*\z/)
      next
    elsif line.start_with?("##")
      next
    elsif (heading = line.match(/^\s*(=+)\s*(.*?)\s*\1\s*$/))
      append_blank_line(result)
      level = [heading[1].length + 1, 6].min
      result << "#{'#' * level} #{heading[2]}"
      result << ""
      in_table = false
      list_indents.clear
      previous_line_was_list_item = false
      next
    elsif line.match?(/^\s*\|\|.*\|\|\s*$/)
      append_blank_line(result) unless in_table
      result << convert_table_line(line)
      unless in_table
        cell_count = line.scan(/\|\|/).length - 1
        result << "| #{Array.new(cell_count, '---').join(' | ')} |"
      end
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
    FileUtils.cp(source, destination)
  end

  references.length
end

attachment_count = 0

Dir.mktmpdir("migrate-moin-linux") do |temporary_root|
  temporary_output_root = File.join(temporary_root, "old")
  temporary_course_output = File.join(temporary_output_root, COURSE_NAME)
  FileUtils.mkdir_p(temporary_course_output)

  course_body = convert_moin(
    COURSE_SOURCE,
    owner: COURSE_NAME,
    context: :course
  )
  course_page = [
    qmd_front_matter(COURSE_NAME),
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
          **源页面不可用**

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
        "**已恢复历史版本**",
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
      context: :child
    )
    page = [
      qmd_front_matter(page_name),
      "[返回“Linux”](../Linux.qmd)",
      "",
      body
    ].join("\n")
    File.write(File.join(temporary_course_output, "#{page_name}.qmd"), page)
  end

  qmd_files = [temporary_course_page] +
              Dir.glob(File.join(temporary_course_output, "*.qmd"))
  attachment_count = copy_referenced_attachments(qmd_files, temporary_course_output)

  FileUtils.rm_rf(COURSE_OUTPUT)
  FileUtils.mv(temporary_course_output, COURSE_OUTPUT)
  FileUtils.cp(temporary_course_page, File.join(OUTPUT_ROOT, "#{COURSE_NAME}.qmd"))
end

puts "Converted #{MIGRATED_PAGES.length} pages"
puts "Copied #{attachment_count} attachments"
