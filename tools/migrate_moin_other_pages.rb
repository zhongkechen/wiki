# frozen_string_literal: true

require "cgi"
require "fileutils"
require "json"
require "pathname"
require "tmpdir"

require_relative "moin_additional_pages"

REPOSITORY_ROOT = File.expand_path("..", __dir__)
DEFAULT_SOURCE_ROOT = File.join(REPOSITORY_ROOT, "mywiki", "data", "pages")
SOURCE_ROOT = File.expand_path(ENV.fetch("MOIN_SOURCE_ROOT", DEFAULT_SOURCE_ROOT))
OUTPUT_ROOT = File.join(REPOSITORY_ROOT, "old")
SOURCE_SNAPSHOT_PATH = File.join(
  __dir__,
  "data",
  "moin_other_page_sources.json"
)
ADDITIONAL_ARCHIVE_ROOT = "其他历史页面"
SYNTHETIC_ROOT_PAGE_NAMES = [ADDITIONAL_ARCHIVE_ROOT].freeze
BASE_ROOT_PAGE_CHILDREN = {
  "维基简介" => [],
  "浙大考博题" => [],
  "计算机体系结构" => [],
  "MSP430" => [],
  "English" => [],
  "美食" => [],
  "有趣的小东东" => ["Two_Numbers"],
  "留言" => [],
  "SICP的Python实现" => %w[
    SICP的Python实现/SICP的Python实现1.1
    SICP的Python实现/SICP的Python实现1.2
    SICP的Python实现/SICP的Python实现1.3
  ],
  "C++集成开发环境" => %w[
    VC++2003
    Dev-C++
    devcpp_简要使用说明
    Eclipse开发C++程序使用说明
    Sun_Netbeans
    Linux下的C++开发环境
    CodeBlock
    Java开发环境
    Cygwin
    MinGW
  ],
  "毕业设计" => %w[
    在线判题题库建设
    开源许可证研究
    Python对象持久化技术研究
    维基网站的研究与建设
  ],
  "cchuang" => [],
  "ymc" => [],
  "lzhongyue" => []
}.freeze
AUXILIARY_PAGE_NAMES = ["留言/PageCommentData"].freeze
EXCLUDED_PAGE_NAMES = [
  "TCPL/B.01.2_Formatted_Output/ugczovkjkeluzdbrjicfhozvfajh"
].freeze
IMAGE_EXTENSIONS = %w[.bmp .gif .jpeg .jpg .png .svg .tif .tiff .webp].freeze
NORMALIZED_TEXT_ATTACHMENT_EXTENSIONS = %w[.js].freeze
EXCLUDED_ATTACHMENTS = {
  "MSP430" => ["ebook 16M.rar"]
}.freeze
REUSED_OUTPUT_PATHS = {
  "论坛" => File.join("ICPC", "论坛.qmd"),
  "Linux" => "Linux.qmd",
  "apache2" => File.join("Linux", "apache2.qmd"),
  "Emacs" => File.join("Linux", "Emacs.qmd"),
  "VI" => File.join("Linux", "VI.qmd"),
  "TeX排版" => File.join("Linux", "TeX排版.qmd"),
  "Python" => File.join("程序设计语言", "Python.qmd"),
  "PythonLdap" => File.join("程序设计语言", "PythonLdap.qmd"),
  "PyGtk" => File.join("程序设计语言", "PyGtk.qmd"),
  "Django" => File.join("程序设计语言", "Django.qmd"),
  "Pygame" => File.join("程序设计语言", "Pygame.qmd"),
  "C" => File.join("高级语言程序设计课程", "C.qmd"),
  "C++" => File.join("程序设计语言", "C++.qmd"),
  "Matlab" => File.join("程序设计语言", "Matlab.qmd"),
  "程序设计语言" => "程序设计语言.qmd",
  "算法" => "算法.qmd",
  "高级语言程序设计课程" => "高级语言程序设计课程.qmd",
  "面向对象程序设计课程" => "面向对象程序设计课程.qmd",
  "数据结构" => "数据结构.qmd",
  "数字图像处理" => "数字图像处理.qmd",
  "Python游戏开发基础" => "Python游戏开发基础.qmd",
  "ICPC" => "ICPC.qmd",
  "计算机科学导论" => "计算机科学导论.qmd",
  "离散数学" => "离散数学.qmd",
  "计算机图形学" => "计算机图形学.qmd",
  "算法与数据结构" => "算法与数据结构.qmd",
  "计算理论" => "计算理论.qmd",
  "科学上网" => File.join("..", "wiki", "科学上网.md"),
  "Tetris" => File.join("..", "wiki", "Tetris.md"),
  "YubiKey" => File.join("..", "wiki", "YubiKey.md"),
  "nostr" => File.join("..", "wiki", "Nostr.md")
}.freeze
SOURCE_TEXT_REPLACEMENTS = {
  "万维网" => {
    "[CSS]]" => "[[CSS]]"
  },
  "常见操作系统" => {
    "*Linux的不足" => "=== Linux的不足 ==="
  },
  "程序" => {
    "[[指令]" => "[[指令]]"
  },
  "基于OpenWrt路由器的全自动翻墙方案" => {
    "[[http://sourceforge.net/projects/xtables-addons/files/|" \
      "xtables-addons源码]" =>
      "[[http://sourceforge.net/projects/xtables-addons/files/|" \
        "xtables-addons源码]]"
  }
}.freeze
UNINDENTED_BULLET_PAGES = %w[
  HTML
  万维网
  入侵检测系统
  常见操作系统
  操作系统历史
  机器语言
  防毒墙
].freeze
SOURCE_CODE_RANGES = {
  "apache2/debianapache2" => [
    ["# a2enmod  userdir", "# /etc/init.d/apache2 force-reload"],
    ["# /etc/init.d/apache2 restart", "# /etc/init.d/apache2 restart"],
    [
      "# mkdir /etc/apache2/passwd",
      "Adding password for user etony"
    ],
    ["# apache2 -l", "mod_so.c"],
    [
      "==== mod-security.conf 文件内容开始====",
      "==== mod-security.conf 文件内容结束===="
    ]
  ]
}.freeze
COURSE_ROOT_NAVIGATION = {
  "C++集成开发环境" =>
    "[返回“高级语言程序设计课程”](<高级语言程序设计课程.qmd>)",
  "TCPL" =>
    "[返回“高级语言程序设计课程”](<高级语言程序设计课程.qmd>)"
}.freeze
BLOCK_TOKEN_PATTERN = /@@MOIN_BLOCK_(\d+)@@/
SECTION_NUMBER_PRAGMA_PATTERN =
  /^#pragma section-numbers (?:on|\d+)[ \t]*\r?$/

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

def page_has_readable_revision?(name)
  !page_revision(name).nil?
end

def page_uses_fallback_revision?(name)
  current_revision = page_current_revision(name)
  selected_revision = page_revision(name)
  current_revision &&
    selected_revision &&
    current_revision != selected_revision
end

tcpl_page_names = (PAGE_INDEX.keys | SOURCE_SNAPSHOT.keys).select do |name|
  name.start_with?("TCPL/") &&
    !EXCLUDED_PAGE_NAMES.include?(name) &&
    page_has_readable_revision?(name)
end.sort
raise "No readable TCPL child pages were found" if tcpl_page_names.empty?

ROOT_PAGE_CHILDREN =
  BASE_ROOT_PAGE_CHILDREN
    .merge("TCPL" => tcpl_page_names)
    .merge(ADDITIONAL_ARCHIVE_ROOT => MOIN_ADDITIONAL_PAGE_NAMES)
    .freeze
MIGRATED_PAGE_NAMES = ROOT_PAGE_CHILDREN.flat_map do |root_name, children|
  [root_name, *children]
end.freeze
SOURCE_PAGE_NAMES = (
  MIGRATED_PAGE_NAMES -
    SYNTHETIC_ROOT_PAGE_NAMES +
    AUXILIARY_PAGE_NAMES
).freeze

missing_pages = SOURCE_PAGE_NAMES.reject do |name|
  PAGE_INDEX.key?(name) || SOURCE_SNAPSHOT.key?(name)
end
raise "Missing source pages: #{missing_pages.join(', ')}" unless missing_pages.empty?

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

def root_page_name(page_name)
  ROOT_PAGE_CHILDREN.each do |root_name, children|
    return root_name if page_name == root_name || children.include?(page_name)
  end
  nil
end

def output_relative_path(page_name)
  root_name = root_page_name(page_name)
  raise "No output root for #{page_name}" unless root_name

  if page_name == root_name
    "#{root_name}.qmd"
  else
    basename = File.basename(page_name).delete("<>")
    File.join(root_name, "#{basename}.qmd")
  end
end

def page_title(page_name)
  MOIN_ADDITIONAL_PAGE_TITLES.fetch(page_name, page_name)
end

def normalize_mixed_indentation(content)
  content.gsub(/^[ ]+\t+/) do |indentation|
    indentation.gsub("\t", "  ")
  end
end

def additional_archive_source
  MOIN_ADDITIONAL_PAGE_GROUPS.map do |group_name, page_names|
    links = page_names.map do |page_name|
      " * [[#{page_name}|#{page_title(page_name)}]]"
    end
    ["= #{group_name} =", *links].join("\n")
  end.join("\n\n")
end

OUTPUT_PATHS = MIGRATED_PAGE_NAMES.to_h do |page_name|
  [page_name, output_relative_path(page_name)]
end.freeze
duplicate_outputs = OUTPUT_PATHS.values.tally.select { |_path, count| count > 1 }
unless duplicate_outputs.empty?
  raise "Duplicate output paths: #{duplicate_outputs.keys.join(', ')}"
end

def markdown_target(path)
  "<#{path}>"
end

def relative_output_path(from_page, target_path)
  from_directory = Pathname.new(File.dirname(output_relative_path(from_page)))
  Pathname.new(target_path)
          .relative_path_from(from_directory)
          .to_s
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

def matching_page_names(pattern, owner)
  if pattern.start_with?("/") && !pattern.match?(/[.*+?\[\](){}|]/)
    target = normalize_page_target(pattern, owner)
    return OUTPUT_PATHS.key?(target) ? [target] : []
  end

  expression =
    if pattern.start_with?("/")
      "^#{Regexp.escape(owner)}#{pattern}"
    else
      pattern.sub(/\Aregex:/, "")
    end
  matcher =
    begin
      Regexp.new(expression)
    rescue RegexpError
      /#{Regexp.escape(expression)}/
    end
  MIGRATED_PAGE_NAMES.select do |page_name|
    page_name.match?(matcher) || page_name.tr("_", " ").match?(matcher)
  end.sort
end

def qmd_front_matter(title, number_sections: false)
  escaped = title.gsub("\\", "\\\\").gsub('"', '\\"')
  number_sections_line = number_sections ? "number-sections: true\n" : ""
  <<~YAML
    ---
    title: "#{escaped}"
    lang: zh
    toc: true
    #{number_sections_line}format:
      html:
        code-copy: true
        html-math-method: mathjax
    ---
  YAML
end

def safe_attachment_name(filename)
  clean = filename.strip.sub(%r{\A\./}, "")
  raise "Unsafe attachment path: #{filename}" if clean.split("/").include?("..")

  clean
end

def attachment_directory(root_name, owner)
  File.join(OUTPUT_ROOT, root_name, "assets", owner)
end

def attachment_names(owner)
  source_directory = page_directory(owner)
  source_attachments =
    source_directory && File.join(source_directory, "attachments")
  if source_attachments && Dir.exist?(source_attachments)
    names = Dir.children(source_attachments).select do |filename|
      File.file?(File.join(source_attachments, filename))
    end.sort
    return names - EXCLUDED_ATTACHMENTS.fetch(owner, [])
  end

  root_name = root_page_name(owner)
  existing_assets = attachment_directory(root_name, owner)
  return [] unless Dir.exist?(existing_assets)

  names = Dir.children(existing_assets).select do |filename|
    File.file?(File.join(existing_assets, filename))
  end.sort
  names - EXCLUDED_ATTACHMENTS.fetch(owner, [])
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

  attachment_list = unlisted.map do |filename|
    " * [[attachment:#{filename}]]"
  end.join("\n")
  [source.rstrip, "", "= 附件 =", attachment_list, ""].join("\n")
end

def asset_output_relative(owner, filename)
  root_name = root_page_name(owner)
  File.join(root_name, "assets", owner, safe_attachment_name(filename))
end

def relative_asset_target(owner, filename)
  current_output = output_relative_path(owner)
  current_directory = Pathname.new(File.dirname(current_output))
  Pathname.new(asset_output_relative(owner, filename))
          .relative_path_from(current_directory)
          .to_s
end

def attachment_markup(spec, owner, image: false)
  filename, label, *options = spec.split("|")
  clean_filename = safe_attachment_name(filename)
  visible = label.to_s.strip
  visible = File.basename(clean_filename) if visible.empty?
  target = markdown_target(relative_asset_target(owner, clean_filename))
  if image || IMAGE_EXTENSIONS.include?(File.extname(clean_filename).downcase)
    "![#{visible}](#{target})#{image_attributes(options)}"
  else
    "[#{visible}](#{target})"
  end
end

def image_attributes(options)
  attributes = options.filter_map do |option|
    key, value = option.strip.split("=", 2)
    next unless %w[width height].include?(key)
    next unless value&.match?(/\A\d+(?:\.\d+)?(?:%|px)?\z/)

    "#{key}=#{value}"
  end
  attributes.empty? ? "" : "{#{attributes.join(' ')}}"
end

def convert_link(raw, owner)
  target, label = raw.split("|", 2)
  target = target.strip
  label = label&.strip
  label = target if label.nil? || label.empty?

  if target.start_with?("attachment:")
    spec = target.delete_prefix("attachment:")
    visible = label.start_with?("attachment:") ? File.basename(spec) : label
    filename = spec.split("|", 2).first
    return "[#{visible}](#{markdown_target(relative_asset_target(owner, filename))})"
  end

  return "[#{label}](#{target})" if target.match?(%r{\A(?:https?|ftp|mailto):})
  return "[#{label}](#{target})" if target.start_with?("#")

  normalized_target = normalize_page_target(CGI.unescapeHTML(target), owner)
  target_path =
    OUTPUT_PATHS[normalized_target] || REUSED_OUTPUT_PATHS[normalized_target]
  return label unless target_path

  path = relative_output_path(owner, target_path)
  "[#{label}](#{markdown_target(path)})"
end

def convert_legacy_external_link(url, label)
  clean_url = CGI.unescapeHTML(url)
  extension = File.extname(clean_url.split(/[?#]/, 2).first).downcase
  return external_image_markup(clean_url, "") if IMAGE_EXTENSIONS.include?(extension)

  visible = label.to_s.strip
  visible = clean_url if visible.empty?
  "[#{visible}](#{clean_url})"
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
    language = Regexp.last_match(1)&.strip.to_s
    language = "cpp" if %w[c++ cplusplus].include?(language.downcase)
    body = Regexp.last_match(2).lines.map(&:rstrip).join("\n").rstrip
    rendered =
      if language == "latex"
        "$$\n#{normalize_latex(body)}\n$$"
      else
        fence_language = language.gsub(/\s.*\z/, "")
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

def wrap_source_code_ranges(source, owner)
  ranges = SOURCE_CODE_RANGES.fetch(owner, [])
  return source if ranges.empty?

  lines = source.lines
  ranges.each do |start_marker, end_marker|
    start_index = lines.index { |line| line.strip == start_marker }
    raise "Missing code range start for #{owner}: #{start_marker}" unless start_index

    end_index = (start_index...lines.length).find do |index|
      lines[index].strip == end_marker
    end
    raise "Missing code range end for #{owner}: #{end_marker}" unless end_index

    body = lines[start_index..end_index].join.rstrip
    lines[start_index..end_index] = ["{{{#!text\n#{body}\n}}}\n"]
  end
  lines.join
end

def convert_wiki_admonitions(text)
  types = {
    "caution" => "warning",
    "note" => "note",
    "tip" => "tip"
  }
  text.gsub(/\{\{\{#!wiki\s+(caution|note|tip)\s*\n(.*?)\}\}\}/m) do
    type = types.fetch(Regexp.last_match(1))
    body = Regexp.last_match(2).rstrip
    "::: {.callout-#{type}}\n#{body}\n:::"
  end
end

def protect_raw_blocks(text)
  fragments = []
  converted = text.gsub(/\{\{\{#!raw\s*\n(.*?)\}\}\}/m) do
    token = "@@MOIN_RAW_#{fragments.length}@@"
    fragments << Regexp.last_match(1).rstrip
    token
  end
  [converted, fragments]
end

def add_display_math_blocks(source, blocks)
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

def protect_nowiki(text)
  fragments = []
  converted = text.gsub(%r{<nowiki>(.*?)</nowiki>}mi) do
    token = "@@MOIN_NOWIKI_#{fragments.length}@@"
    fragments << CGI.escapeHTML(Regexp.last_match(1))
    token
  end
  [converted, fragments]
end

def protect_posix_character_classes(text)
  fragments = []
  converted = text.gsub(/\[\[:[a-z]+:\]\]/i) do
    token = "@@MOIN_POSIX_#{fragments.length}@@"
    fragments << Regexp.last_match(0)
    token
  end
  [converted, fragments]
end

def normalize_indented_outline(source, owner)
  return source unless owner == "计算机体系结构"

  source.lines.map do |line|
    match = line.match(/\A([ ]{3,})(\S.*?)(\n?)\z/)
    next line unless match

    content = match[2]
    next line if content.match?(/\A(?:\*|\d+\.|[a-z]\.)\s+/i)
    next line if content.match?(BLOCK_TOKEN_PATTERN)

    "#{match[1]}* #{content}#{match[3]}"
  end.join
end

def external_image_markup(url, label, options = [])
  visible = label.to_s.empty? ? File.basename(url.split(/[?#]/, 2).first) : label
  "![#{visible}](#{url})#{image_attributes(options)}"
end

def render_page_list(pattern, owner)
  matching_page_names(pattern, owner).map do |page_name|
    title = page_name
    if page_name.start_with?("TCPL/")
      title = page_source(page_name).lines.filter_map do |line|
        heading = line.match(/^\s*(=+)\s*(.*?)\s*\1\s*$/)
        heading && heading[2]
      end.first
      title = File.basename(page_name).tr("_", " ") if title.to_s.empty?
    end
    " * [[#{page_name}|#{title}]]"
  end.join("\n")
end

def render_content_with_blocks(
  content,
  blocks,
  first_prefix: "",
  continuation_prefix: ""
)
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
    cell.strip.sub(/\A(?:<(?:#[0-9a-fA-F]+|[^>]*=[^>]*)>\s*)+/, "")
  end
end

def convert_table_line(cells)
  escaped = cells.map do |cell|
    cell.gsub("\\") { "\\\\" }.gsub("|", "\\|")
  end
  "| #{escaped.join(' | ')} |"
end

def escape_plain_moin_markup(source)
  source.gsub!(
    /(\|\|)\s*(?:<(?:#[0-9a-fA-F]+|[^>\n]*=[^>\n]*)>\s*)+/
  ) { Regexp.last_match(1) }

  source.lines.map do |line|
    table = line.match?(/^\s*\|\|.*\|\|\s*$/)
    bullet = line.match(/\A(\s+)\*\s/)
    quote = line.match?(/\A>\s/)
    line = line.sub(/\A(\s+)\*/, '\1@@MOIN_BULLET@@') if bullet
    line = line.sub(/\A>/, "@@MOIN_QUOTE@@") if quote
    line = line.gsub("\\") { "\\\\" } unless table
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
    converted.gsub!(/''([^'\n]*?)''/) do
      markdown_emphasis(Regexp.last_match(1), "*")
    end
    converted.gsub(/--\((.*?)\)--/) do
      markdown_emphasis(Regexp.last_match(1), "~~")
    end
  end.join
end

def normalize_unindented_bullets(page_name, source)
  return source unless UNINDENTED_BULLET_PAGES.include?(page_name)

  source.lines.map do |line|
    match = line.match(/\A(\*+)([^\n]*)(\n?)\z/)
    next line unless match

    content = match[2].strip
    "#{' ' * match[1].length}* #{content}#{match[3]}"
  end.join
end

def list_item_match(line)
  line.match(/^(\s+)(\*|\d+\.|[a-z]\.)(?:[ \t]+(.*))?$/i) ||
    line.match(/^(\s+)(\d+、)\s*(.*)$/)
end

def convert_moin(text, owner:)
  source = text.gsub("\r\n", "\n")
  SOURCE_TEXT_REPLACEMENTS.fetch(owner, {}).each do |before, after|
    source.gsub!(before, after)
  end
  source = normalize_unindented_bullets(owner, source)
  source = wrap_source_code_ranges(source, owner)
  source.gsub!(/^#pragma section-numbers (?:on|off|\d+)[ \t]*\n?/, "")
  source.gsub!("[[TableOfContents]]", "<<TableOfContents>>")
  source.gsub!("[[AttachList]]", "<<AttachList>>")
  source.gsub!("{{{{#!", "{{{#!")
  source.gsub!(/^(\s*)\{\{\{(?!#!)[ \t]*(\S[^\n]*)\n/) do
    "#{Regexp.last_match(1)}{{{\n#{Regexp.last_match(2)}\n"
  end
  source = include_unlisted_attachments(source, owner)
  source.gsub!(/<<PageList\(([^)]+)\)>>/) do
    render_page_list(Regexp.last_match(1), owner)
  end
  source.gsub!(/<<Include\(([^,)]+),[^)]*titlesonly[^)]*\)>>/) do
    render_page_list(Regexp.last_match(1), owner)
  end
  source.gsub!(/<<Include\(\^?([^,)]+)(?:,[^)]*)?\)>>/) do
    target = normalize_page_target(Regexp.last_match(1), owner)
    OUTPUT_PATHS.key?(target) ? "[[#{target}]]" : ""
  end
  source.gsub!(/<<FootNote\((.*?)\)>>/m) do
    "@@MOIN_FOOTNOTE_OPEN@@#{Regexp.last_match(1)}@@MOIN_FOOTNOTE_CLOSE@@"
  end

  source = convert_wiki_admonitions(source)
  source, raw = protect_raw_blocks(source)
  source, nowiki = protect_nowiki(source)
  source.gsub!(%r{</?center>}i, "")
  source.gsub!(%r{<br\s*/?>}i, "<<BR>>")
  source, blocks, inline = convert_blocks(source)
  source = add_display_math_blocks(source, blocks)
  source = normalize_indented_outline(source, owner)
  source.gsub!("<<AttachList>>", render_attach_list(owner))
  source = escape_plain_moin_markup(source)

  source.gsub!(/\{\{attachment:([^}\n]+)\}\}/) do
    attachment_markup(Regexp.last_match(1), owner, image: true)
  end
  source.gsub!(/\{\{(https?:\/\/[^}\n]+)\}\}/) do
    url, label, *options = Regexp.last_match(1).split("|")
    external_image_markup(url, label, options)
  end
  source.gsub!(
    /(?<!\[)\[((?:https?|ftp|mailto):[^\]\s]+)(?:\s+([^\]\n]+))?\](?!\])/
  ) do
    convert_legacy_external_link(Regexp.last_match(1), Regexp.last_match(2))
  end
  source, posix_character_classes = protect_posix_character_classes(source)
  source.gsub!(/\[\[([^\]]+)\]\]/) do
    convert_link(Regexp.last_match(1), owner)
  end
  source.gsub!(/\]\((?!<|(?:https?|ftp|mailto):|#)/, "] (")
  source.gsub!("@@MOIN_FOOTNOTE_OPEN@@", "^[")
  source.gsub!("@@MOIN_FOOTNOTE_CLOSE@@", "]")
  source.gsub!("<<BR>>", "<br>")
  source.gsub!(/<<(?:TableOfContents|Navigation\([^)]*\))>>/, "")
  source.gsub!(/<<Anchor\(([^)]+)\)>>/, '<a id="\1"></a>')
  source.gsub!(/<<[^>]+>>/, "")
  source = convert_moin_emphasis(source)

  result = []
  in_table = false
  list_indents = []
  list_alpha_counters = []
  previous_line_was_list_item = false

  source.each_line do |raw_line|
    line = raw_line.rstrip

    if line.match?(/\A\s*Category\S+(?:\s+Category\S+)*\s*\z/)
      next
    elsif line.start_with?("##", "#acl", "#format")
      next
    elsif (heading = line.match(/^\s*(=+)\s*(.*?)\s*\1\s*$/))
      append_blank_line(result)
      level = [heading[1].length + 1, 6].min
      result << "#{'#' * level} #{heading[2]}"
      result << ""
      in_table = false
      list_indents.clear
      list_alpha_counters.clear
      previous_line_was_list_item = false
      next
    elsif line.match?(/^\s*-{4,}\s*$/)
      append_blank_line(result)
      result << "---"
      result << ""
      in_table = false
      list_indents.clear
      list_alpha_counters.clear
      previous_line_was_list_item = false
      next
    elsif line.match?(/^\s*\|\|.*\|\|\s*$/)
      append_blank_line(result) unless in_table
      cells = table_cells(line)
      result << convert_table_line(cells)
      unless in_table
        result << "| #{Array.new(cells.length, '---').join(' | ')} |"
      end
      in_table = true
      list_indents.clear
      list_alpha_counters.clear
      previous_line_was_list_item = false
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
      list_alpha_counters = list_alpha_counters.take(depth + 1)
      item_content = list[3].to_s
      marker =
        if list[2].end_with?("、") || list[2].match?(/\A[iI]\.\z/)
          list_alpha_counters[depth] = nil
          "1."
        elsif root_page_name(owner) == ADDITIONAL_ARCHIVE_ROOT &&
            list[2].match?(/\A[a-z]\.\z/i)
          counter = list_alpha_counters[depth].to_i
          list_alpha_counters[depth] = counter + 1
          base = list[2].match?(/\A[A-Z]/) ? "A".ord : "a".ord
          item_content = "#{(base + counter).chr}. #{item_content}"
          "*"
        else
          list_alpha_counters[depth] = nil
          list[2]
        end
      prefix = "#{indent}#{marker} "
      continuation = " " * prefix.length
      result.concat(
        render_content_with_blocks(
          item_content,
          blocks,
          first_prefix: prefix,
          continuation_prefix: continuation
        )
      )
      previous_line_was_list_item = true
    elsif (definition = line.match(/^\s+(.+?)::\s*(.*)$/))
      append_blank_line(result) unless list_indents.empty?
      list_indents.clear
      list_alpha_counters.clear
      result << "**#{definition[1]}**: #{definition[2]}"
      previous_line_was_list_item = false
    else
      if line.empty?
        append_blank_line(result)
      elsif !list_indents.empty? &&
            (indented = line.match(/^(\s+)(.*)$/)) &&
            (parent_depth =
              list_indents.rindex { |indent| indent < indented[1].length })
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
        list_alpha_counters.clear
        result.concat(render_content_with_blocks(line, blocks))
      end
      previous_line_was_list_item = false
    end
  end

  rendered = result.join("\n")
  raise "Unexpanded MoinMoin block token" if rendered.match?(BLOCK_TOKEN_PATTERN)

  inline.each_with_index do |code, index|
    rendered.gsub!("@@MOIN_INLINE_#{index}@@") { code }
  end
  raw.each_with_index do |content, index|
    rendered.gsub!("@@MOIN_RAW_#{index}@@") { content }
  end
  nowiki.each_with_index do |content, index|
    rendered.gsub!("@@MOIN_NOWIKI_#{index}@@") { content }
  end
  posix_character_classes.each_with_index do |content, index|
    rendered.gsub!("@@MOIN_POSIX_#{index}@@") { content }
  end
  rendered.gsub!(/\n{3,}/, "\n\n")
  rendered.strip + "\n"
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
    next if body.include?("Add your comment") &&
            body.include?("MoinMoin Powered")

    { author: author, timestamp: timestamp, body: body }
  end
end

def render_page_comments(owner)
  comments = page_comments(owner)
  return "" if comments.empty?

  rendered = comments.map do |comment|
    body = convert_moin(comment[:body], owner: owner)
    quoted_body = body.lines.map do |line|
      line.strip.empty? ? ">" : "> #{line.rstrip}"
    end.join("\n")
    [
      "> **#{comment[:author]}** · #{comment[:timestamp]}",
      ">",
      quoted_body
    ].join("\n")
  end.join("\n\n")
  "## 评论存档\n\n#{rendered}\n"
end

def source_with_revision_notice(page_name)
  return additional_archive_source if SYNTHETIC_ROOT_PAGE_NAMES.include?(page_name)

  source = page_source(page_name)
  content =
    if !page_has_readable_revision?(page_name)
      <<~MARKDOWN
        ::: {.callout-warning}
        '''源页面不可用'''

        MoinMoin 备份中保留了这个页面名，但没有可读取的版本。
        :::
      MARKDOWN
    elsif source.strip.empty?
      "::: {.callout-note}\n原 MoinMoin 页面暂无正文内容。\n:::\n"
    else
      source
    end

  return content unless page_uses_fallback_revision?(page_name)

  [
    "::: {.callout-warning}",
    "'''已恢复历史版本'''",
    "",
    "当前版本 #{page_current_revision(page_name)} 在备份中缺失；" \
      "以下内容来自最新可读取版本 #{page_revision(page_name)}。",
    ":::",
    "",
    content
  ].join("\n")
end

def attachment_source(owner, filename)
  source_directory = page_directory(owner)
  source =
    source_directory &&
    File.join(source_directory, "attachments", filename)
  return source if source && File.file?(source)

  root_name = root_page_name(owner)
  existing = File.join(attachment_directory(root_name, owner), filename)
  return existing if File.file?(existing)

  nil
end

page_count = 0
attachment_count = 0

Dir.mktmpdir("migrate-moin-other-pages") do |temporary_root|
  temporary_output_root = File.join(temporary_root, "old")
  FileUtils.mkdir_p(temporary_output_root)

  MIGRATED_PAGE_NAMES.each do |page_name|
    source = source_with_revision_notice(page_name)
    body = convert_moin(source, owner: page_name)
    body = [body.rstrip, "", render_page_comments(page_name)].join("\n") \
      if page_name == "留言"

    root_name = root_page_name(page_name)
    navigation =
      if page_name == root_name
        COURSE_ROOT_NAVIGATION.fetch(
          root_name,
          "[返回旧版首页](首页.qmd)"
        )
      else
        "[返回“#{root_name}”](<../#{root_name}.qmd>)"
      end
    page = [
      qmd_front_matter(
        page_title(page_name),
        number_sections: page_source(page_name).match?(
          SECTION_NUMBER_PRAGMA_PATTERN
        )
      ),
      navigation,
      "",
      body
    ].join("\n")
    page = normalize_mixed_indentation(page) \
      if root_name == ADDITIONAL_ARCHIVE_ROOT
    destination =
      File.join(temporary_output_root, output_relative_path(page_name))
    FileUtils.mkdir_p(File.dirname(destination))
    File.write(destination, page)
    page_count += 1
  end

  MIGRATED_PAGE_NAMES.each do |owner|
    attachment_names(owner).each do |filename|
      source = attachment_source(owner, filename)
      raise "Missing source attachment for #{owner}/#{filename}" unless source

      destination =
        File.join(temporary_output_root, asset_output_relative(owner, filename))
      FileUtils.mkdir_p(File.dirname(destination))
      if root_page_name(owner) == ADDITIONAL_ARCHIVE_ROOT &&
          NORMALIZED_TEXT_ATTACHMENT_EXTENSIONS.include?(
            File.extname(filename).downcase
          )
        File.binwrite(
          destination,
          normalize_mixed_indentation(File.binread(source))
        )
      else
        FileUtils.cp(source, destination)
      end
      attachment_count += 1
    end
  end

  ROOT_PAGE_CHILDREN.each_key do |root_name|
    source_page = File.join(temporary_output_root, "#{root_name}.qmd")
    destination_page = File.join(OUTPUT_ROOT, "#{root_name}.qmd")
    FileUtils.cp(source_page, destination_page)

    source_directory = File.join(temporary_output_root, root_name)
    destination_directory = File.join(OUTPUT_ROOT, root_name)
    FileUtils.rm_rf(destination_directory)
    FileUtils.mv(source_directory, destination_directory) \
      if Dir.exist?(source_directory)
  end
end

puts "Converted #{page_count} pages"
puts "Copied #{attachment_count} attachments"
