# frozen_string_literal: true

require "fileutils"
require "json"
require "tmpdir"

DEFAULT_SOURCE_ROOT = File.expand_path("../mywiki/data/pages", __dir__)
SOURCE_ROOT = File.expand_path(ENV.fetch("MOIN_SOURCE_ROOT", DEFAULT_SOURCE_ROOT))
OUTPUT_ROOT = File.expand_path("../old", __dir__)
PAGE_NAME = "算法"
PAGE_TITLE = "算法"
SOURCE_SNAPSHOT_PATH = File.expand_path("data/moin_algorithm_sources.json", __dir__)
TOPIC_PAGE_NAMES = %w[
  算法专题：动态规划
  算法专题：搜索
  算法专题：贪婪算法
  算法专题：递推求解
].freeze

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

page_directory =
  page_index[PAGE_NAME] && File.join(SOURCE_ROOT, page_index.fetch(PAGE_NAME))
current_revision =
  if page_directory && File.exist?(File.join(page_directory, "current"))
    File.read(File.join(page_directory, "current")).strip
  else
    snapshot.dig(PAGE_NAME, "current_revision")
  end
revision =
  if page_directory
    revisions_directory = File.join(page_directory, "revisions")
    current_path =
      current_revision && File.join(revisions_directory, current_revision)
    if current_path && File.file?(current_path)
      current_revision
    elsif Dir.exist?(revisions_directory)
      Dir.children(revisions_directory).select do |entry|
        File.file?(File.join(revisions_directory, entry))
      end.max
    end
  else
    snapshot.dig(PAGE_NAME, "revision")
  end
source =
  if page_directory && revision
    File.read(
      File.join(page_directory, "revisions", revision),
      encoding: "UTF-8",
      invalid: :replace
    )
  else
    snapshot.dig(PAGE_NAME, "source")
  end

unless source
  raise <<~MESSAGE
    MoinMoin source data for #{PAGE_NAME} was not found.
    Set MOIN_SOURCE_ROOT to a data/pages directory or restore #{SOURCE_SNAPSHOT_PATH}.
  MESSAGE
end

if page_directory
  source_snapshot = {
    PAGE_NAME => {
      "source" => source,
      "revision" => revision,
      "current_revision" => current_revision
    }
  }
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

def page_list(pattern)
  pages = TOPIC_PAGE_NAMES.select { |page_name| page_name.include?(pattern) }
  pages.map do |page_name|
    "* [#{page_name}](<ICPC/#{page_name}.qmd>)"
  end.join("\n")
end

def convert_moin(text)
  source = text.gsub("\r\n", "\n")
  source.gsub!(/<<PageList\(([^)]+)\)>>/) { page_list(Regexp.last_match(1)) }
  source.gsub!(/<<[^>]+>>/, "")
  source.gsub!(%r{(?<![\[<(])https?://[^\s>]+}) { |url| "<#{url}>" }

  result = []
  source.each_line do |raw_line|
    line = raw_line.rstrip
    if (heading = line.match(/^\s*(=+)\s*(.*?)\s*\1\s*$/))
      result << "" unless result.empty? || result.last.empty?
      level = [heading[1].length + 1, 6].min
      result << "#{'#' * level} #{heading[2]}"
      result << ""
    elsif (list = line.match(/^\s+\*\s+(.*)$/))
      result << "* #{list[1]}"
    else
      result << line
    end
  end

  result.join("\n").gsub(/\n{3,}/, "\n\n").strip + "\n"
end

missing_topics = TOPIC_PAGE_NAMES.reject do |page_name|
  File.exist?(File.join(OUTPUT_ROOT, "ICPC", "#{page_name}.qmd"))
end
unless missing_topics.empty?
  raise "Missing migrated algorithm child pages: #{missing_topics.join(', ')}"
end

page = [
  qmd_front_matter(PAGE_TITLE),
  "[返回旧版首页](首页.qmd)",
  "",
  convert_moin(source)
].join("\n")

Dir.mktmpdir("migrate-moin-algorithm") do |temporary_root|
  temporary_page = File.join(temporary_root, "#{PAGE_NAME}.qmd")
  File.write(temporary_page, page)
  FileUtils.mv(temporary_page, File.join(OUTPUT_ROOT, "#{PAGE_NAME}.qmd"))
end

puts "Converted 1 page"
puts "Reused #{TOPIC_PAGE_NAMES.length} existing child pages"
