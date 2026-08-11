# frozen_string_literal: true

require "fileutils"
require "json"
require "tmpdir"

DEFAULT_SOURCE_ROOT = File.expand_path("../mywiki/data/pages", __dir__)
SOURCE_ROOT = File.expand_path(ENV.fetch("MOIN_SOURCE_ROOT", DEFAULT_SOURCE_ROOT))
OUTPUT_ROOT = File.expand_path("../old", __dir__)
COURSE_NAME = "计算理论"
COURSE_OUTPUT = File.join(OUTPUT_ROOT, COURSE_NAME)
SOURCE_SNAPSHOT_PATH = File.expand_path(
  "data/moin_computation_theory_sources.json",
  __dir__
)
CHILD_PAGE_NAMES = %w[
  集合、关系和语言
  有穷自动机
  上下文无关语言
  图灵机
  不可判定性
  计算复杂性
  NP完全性
].freeze
MIGRATED_PAGE_NAMES = ([COURSE_NAME] + CHILD_PAGE_NAMES).freeze

def decode_page_name(entry)
  entry.gsub(/\(([0-9a-fA-F]+)\)/) do
    [$1].pack("H*").force_encoding("UTF-8")
  end
end

page_index =
  if Dir.exist?(SOURCE_ROOT)
    Dir.children(SOURCE_ROOT).to_h do |entry|
      [decode_page_name(entry), entry]
    end
  else
    {}
  end

snapshot =
  if File.exist?(SOURCE_SNAPSHOT_PATH)
    JSON.parse(File.read(SOURCE_SNAPSHOT_PATH, encoding: "UTF-8"))
  else
    {}
  end

if page_index.empty? && snapshot.empty?
  raise <<~MESSAGE
    MoinMoin source data was not found.
    Set MOIN_SOURCE_ROOT to a data/pages directory or restore #{SOURCE_SNAPSHOT_PATH}.
  MESSAGE
end

def page_directory(name, page_index)
  entry = page_index[name]
  entry && File.join(SOURCE_ROOT, entry)
end

def snapshot_record(name, snapshot)
  record = snapshot[name]
  return {} unless record

  record.is_a?(Hash) ? record : { "source" => record }
end

def page_current_revision(name, page_index, snapshot)
  directory = page_directory(name, page_index)
  return snapshot_record(name, snapshot)["current_revision"] unless directory

  current_path = File.join(directory, "current")
  return nil unless File.exist?(current_path)

  File.read(current_path).strip
end

def page_revision(name, page_index, snapshot)
  directory = page_directory(name, page_index)
  return snapshot_record(name, snapshot)["revision"] unless directory

  revisions_directory = File.join(directory, "revisions")
  return nil unless Dir.exist?(revisions_directory)

  current_revision = page_current_revision(name, page_index, snapshot)
  current_path =
    current_revision && File.join(revisions_directory, current_revision)
  return current_revision if current_path && File.file?(current_path)

  Dir.children(revisions_directory).select do |revision|
    File.file?(File.join(revisions_directory, revision))
  end.max
end

def page_source(name, page_index, snapshot)
  directory = page_directory(name, page_index)
  unless directory
    return snapshot_record(name, snapshot).fetch("source", "")
  end

  revision = page_revision(name, page_index, snapshot)
  return "" unless revision

  File.read(
    File.join(directory, "revisions", revision),
    encoding: "UTF-8",
    invalid: :replace
  )
end

missing_pages = MIGRATED_PAGE_NAMES.reject do |name|
  !page_source(name, page_index, snapshot).strip.empty?
end
unless missing_pages.empty?
  raise "Missing readable source pages: #{missing_pages.join(', ')}"
end

if page_index.any?
  source_snapshot = MIGRATED_PAGE_NAMES.to_h do |name|
    [
      name,
      {
        "source" => page_source(name, page_index, snapshot),
        "revision" => page_revision(name, page_index, snapshot),
        "current_revision" => page_current_revision(name, page_index, snapshot)
      }
    ]
  end
  FileUtils.mkdir_p(File.dirname(SOURCE_SNAPSHOT_PATH))
  File.write(
    SOURCE_SNAPSHOT_PATH,
    JSON.pretty_generate(source_snapshot) + "\n"
  )
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

def normalize_latex(content)
  formula = content.lines.map(&:rstrip).join("\n").strip
  if formula.start_with?("$$") && formula.end_with?("$$")
    formula = formula.delete_prefix("$$").delete_suffix("$$").strip
  elsif formula.start_with?("$") && formula.end_with?("$")
    formula = formula.delete_prefix("$").delete_suffix("$").strip
  end
  formula
end

def page_link(target, context)
  clean_target = target.sub(/\A\^/, "")

  if clean_target == COURSE_NAME
    context == :course ? "#{COURSE_NAME}.qmd" : "../#{COURSE_NAME}.qmd"
  elsif CHILD_PAGE_NAMES.include?(clean_target)
    context == :course ? "#{COURSE_NAME}/#{clean_target}.qmd" : "#{clean_target}.qmd"
  else
    context == :course ? "#{clean_target}.html" : "../#{clean_target}.html"
  end
end

def markdown_target(path)
  "<#{path}>"
end

def convert_link(raw, context)
  target, label = raw.split("|", 2)
  label ||= target

  return "[#{label}](#{target})" if target.match?(%r{\A(?:https?|ftp|mailto):})
  return "[#{label}](#{target})" if target.start_with?("#")

  "[#{label}](#{markdown_target(page_link(target, context))})"
end

def append_blank_line(result)
  result << "" unless result.empty? || result.last.empty?
end

def convert_moin(text, context:)
  source = text.gsub("\r\n", "\n")
  source.gsub!(/^#format\s+\S+\s*$\n?/, "")
  source.gsub!(/<<latex\((.*?)\)>>/m) do
    "$#{normalize_latex(Regexp.last_match(1))}$"
  end
  source.gsub!(/\[\[([^\]]+)\]\]/) do
    convert_link(Regexp.last_match(1), context)
  end
  source.gsub!(/'''(.*?)'''/m, '**\1**')
  source.gsub!(/''(.*?)''/m, '*\1*')
  source.gsub!("&asymp;,,L,,", '$\asymp_L$')
  source.gsub!(/<<[^>]+>>/, "")

  result = []
  list_indents = []

  source.each_line do |raw_line|
    line = raw_line.rstrip

    if (heading = line.match(/^\s*(=+)\s*(.*?)\s*\1\s*$/))
      append_blank_line(result)
      level = [heading[1].length + 1, 6].min
      result << "#{'#' * level} #{heading[2]}"
      result << ""
      list_indents.clear
    elsif (list = line.match(/^(\s+)(\*|\d+\.|[a-z]\.)\s+(.*)$/i))
      source_indent = list[1].length
      if list_indents.empty?
        append_blank_line(result)
        list_indents << source_indent
      elsif source_indent > list_indents.last
        list_indents << source_indent
      elsif source_indent < list_indents.last
        list_indents.pop while list_indents.length > 1 &&
                               source_indent < list_indents.last
      end

      depth = list_indents.index(source_indent) || list_indents.length - 1
      indent = " " * (depth * 4)
      marker = list[2] == "*" ? "*" : "1."
      result << "#{indent}#{marker} #{list[3]}"
    elsif line.empty?
      append_blank_line(result)
      list_indents.clear
    else
      append_blank_line(result) unless list_indents.empty?
      list_indents.clear
      result << line
    end
  end

  rendered = result.join("\n").gsub(/\n{3,}/, "\n\n").strip + "\n"
  raise "MoinMoin macro leaked into output" if rendered.include?("<<")
  raise "MoinMoin link leaked into output" if rendered.include?("[[")

  rendered
end

Dir.mktmpdir("migrate-moin-computation-theory") do |temporary_root|
  temporary_output_root = File.join(temporary_root, "old")
  temporary_course_output = File.join(temporary_output_root, COURSE_NAME)
  FileUtils.mkdir_p(temporary_course_output)

  course_page = [
    qmd_front_matter(COURSE_NAME),
    "[返回旧版首页](首页.qmd)",
    "",
    convert_moin(
      page_source(COURSE_NAME, page_index, snapshot),
      context: :course
    )
  ].join("\n")
  File.write(
    File.join(temporary_output_root, "#{COURSE_NAME}.qmd"),
    course_page
  )

  CHILD_PAGE_NAMES.each do |page_name|
    page = [
      qmd_front_matter(page_name),
      "[返回“#{COURSE_NAME}”](../#{COURSE_NAME}.qmd)",
      "",
      convert_moin(
        page_source(page_name, page_index, snapshot),
        context: :child
      )
    ].join("\n")
    File.write(
      File.join(temporary_course_output, "#{page_name}.qmd"),
      page
    )
  end

  FileUtils.mkdir_p(OUTPUT_ROOT)
  FileUtils.rm_rf(COURSE_OUTPUT)
  FileUtils.mv(temporary_course_output, COURSE_OUTPUT)
  FileUtils.mv(
    File.join(temporary_output_root, "#{COURSE_NAME}.qmd"),
    File.join(OUTPUT_ROOT, "#{COURSE_NAME}.qmd")
  )
end

puts "Converted #{MIGRATED_PAGE_NAMES.length} pages"
puts "Copied 0 attachments (legacy formula images replaced by MathJax)"
