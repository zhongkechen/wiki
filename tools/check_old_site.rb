# frozen_string_literal: true

require "cgi"
require "uri"

REPOSITORY_ROOT = File.expand_path("..", __dir__)
SOURCE_ROOT = File.join(REPOSITORY_ROOT, "old")
SITE_ROOT = File.expand_path(
  ARGV.fetch(0, File.join(REPOSITORY_ROOT, "_site"))
)

qmd_files = Dir.glob(File.join(SOURCE_ROOT, "**", "*.qmd")).sort
html_files = Dir.glob(File.join(SITE_ROOT, "old", "**", "*.html")).sort

expected_html = qmd_files.map do |qmd_file|
  relative = qmd_file.delete_prefix("#{SOURCE_ROOT}/").sub(/\.qmd\z/, ".html")
  File.join(SITE_ROOT, "old", relative)
end
missing_html = expected_html.reject { |html_file| File.file?(html_file) }

unless missing_html.empty?
  abort "Missing rendered pages:\n#{missing_html.join("\n")}"
end

unexpected_html = html_files - expected_html
unless unexpected_html.empty?
  abort "Unexpected rendered pages:\n#{unexpected_html.join("\n")}"
end

conversion_errors = []

qmd_files.each do |qmd_file|
  relative_qmd = qmd_file.delete_prefix("#{REPOSITORY_ROOT}/")
  File.foreach(qmd_file, encoding: "UTF-8").with_index(1) do |line, line_number|
    if line.match?(/\A\\\*+/)
      conversion_errors <<
        "#{relative_qmd}:#{line_number}: unconverted list marker"
    end
    if line.include?("attachment:")
      conversion_errors <<
        "#{relative_qmd}:#{line_number}: unconverted attachment reference"
    end
    if line.match?(/\]\((?:https?|ftp|mailto):[^)\n]*\s+[^)\n]*\)/i)
      conversion_errors <<
        "#{relative_qmd}:#{line_number}: external link target contains spaces"
    end
  end
end

unless conversion_errors.empty?
  abort "Conversion residue:\n#{conversion_errors.join("\n")}"
end

broken_links = []

html_files.each do |html_file|
  html = File.read(html_file, encoding: "UTF-8", invalid: :replace)
  html.scan(/(?:href|src)=(["'])(.*?)\1/i).each do |_quote, raw_target|
    target = CGI.unescapeHTML(raw_target)
    next if target.empty? || target.start_with?("#", "//")
    next if target.match?(%r{\A(?:https?|ftp|mailto|data|javascript):}i)

    path = target.split(/[?#]/, 2).first
    next if path.empty?

    begin
      path = URI::DEFAULT_PARSER.unescape(path)
    rescue ArgumentError
      broken_links << "#{html_file}: #{target} (invalid URI encoding)"
      next
    end

    resolved =
      if path.start_with?("/")
        File.join(SITE_ROOT, path.sub(%r{\A/+}, ""))
      else
        File.expand_path(path, File.dirname(html_file))
      end
    next if File.exist?(resolved)
    next if File.exist?(File.join(resolved, "index.html"))

    relative_html = html_file.delete_prefix("#{SITE_ROOT}/")
    broken_links << "#{relative_html}: #{target}"
  end
end

unless broken_links.empty?
  abort "Broken local links:\n#{broken_links.uniq.sort.join("\n")}"
end

puts "Validated #{html_files.length} old pages with no broken local links"
