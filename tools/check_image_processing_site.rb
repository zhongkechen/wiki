# frozen_string_literal: true

require "cgi"
require "uri"

repository_root = File.expand_path("..", __dir__)
site_root = File.expand_path(ARGV.fetch(0, File.join(repository_root, "_site")))
source_root = File.join(repository_root, "old")

qmd_files = [
  File.join(source_root, "数字图像处理.qmd"),
  *Dir.glob(File.join(source_root, "数字图像处理", "*.qmd"))
]
html_files = qmd_files.map do |qmd_file|
  relative = qmd_file.delete_prefix("#{source_root}/").sub(/\.qmd\z/, ".html")
  File.join(site_root, "old", relative)
end

missing_pages = html_files.reject { |html_file| File.exist?(html_file) }
unless missing_pages.empty?
  abort "Missing rendered pages:\n#{missing_pages.join("\n")}"
end

broken_links = []
markdown_artifacts = []

html_files.each do |html_file|
  html = File.read(html_file, encoding: "UTF-8")

  html.scan(/(?:href|src)="([^"]+)"/).flatten.each do |raw_target|
    target = CGI.unescapeHTML(raw_target)
    next if target.empty? || target.start_with?("#", "//")
    next if target.match?(%r{\A(?:https?:|mailto:|data:|javascript:)})

    path = URI::DEFAULT_PARSER.unescape(target.split(/[?#]/, 2).first)
    next if path.empty?

    resolved =
      if path.start_with?("/")
        File.join(site_root, path.sub(%r{\A/+}, ""))
      else
        File.expand_path(path, File.dirname(html_file))
      end
    next if File.exist?(resolved) || File.exist?(File.join(resolved, "index.html"))

    broken_links << "#{html_file.delete_prefix("#{site_root}/")}: #{target}"
  end

  html.each_line.with_index(1) do |line, line_number|
    next unless line.match?(%r{<(?:p|li)\b[^>]*>.*(?:\#{2,6}\s|\s(?:\*|1\.)\s)})

    markdown_artifacts << "#{html_file.delete_prefix("#{site_root}/")}:#{line_number}"
  end
end

unless broken_links.empty?
  abort "Broken local links:\n#{broken_links.uniq.sort.join("\n")}"
end

unless markdown_artifacts.empty?
  abort "Rendered Markdown markers found inside prose:\n#{markdown_artifacts.join("\n")}"
end

structure_checks = {
  "图像频域增强实验.html" => /<li>傅立叶频谱和平均值\s*<ol\b/m,
  "图像压缩实验.html" => /<li>图像的熵\(Entropy\)\s*<ol\b/m,
  "数学形态学处理实验.html" => /<li>边界提取\s*<ol\b/m,
  "彩色图像处理实验.html" => /<li>Web-Safe颜色.*?\s*<ol\b/m
}

structure_checks.each do |filename, pattern|
  html_file = File.join(site_root, "old", "数字图像处理", filename)
  html = File.read(html_file, encoding: "UTF-8")
  abort "Nested list structure is missing from #{filename}" unless html.match?(pattern)
end

puts "Validated #{html_files.length} image-processing pages with no broken local links"
