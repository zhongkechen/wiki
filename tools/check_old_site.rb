# frozen_string_literal: true

require "cgi"
require "uri"

REPOSITORY_ROOT = File.expand_path("..", __dir__)
SOURCE_ROOT = File.join(REPOSITORY_ROOT, "old")
SITE_ROOT = File.expand_path(
  ARGV.fetch(0, File.join(REPOSITORY_ROOT, "_site"))
)

# Extract Markdown link bodies without truncating URLs that contain parentheses.
def markdown_link_bodies(line)
  bodies = []
  offset = 0

  while (opening = line.index("](", offset))
    body_start = opening + 2
    index = body_start
    depth = 1
    quote = nil

    while index < line.length
      character = line[index]
      if character == "\\"
        index += 2
        next
      elsif quote
        quote = nil if character == quote
      elsif depth == 1 &&
          %w[" '].include?(character) &&
          index > body_start &&
          line[index - 1].match?(/[ \t]/)
        quote = character
      elsif character == "("
        depth += 1
      elsif character == ")"
        depth -= 1
        if depth.zero?
          bodies << line[body_start...index]
          offset = index + 1
          break
        end
      end
      index += 1
    end

    break unless depth.zero?
  end

  bodies
end

def external_link_target_contains_spaces?(body)
  target = body.strip
  return false unless target.match?(%r{\A(?:https?|ftp|mailto):}i)
  return false if target.start_with?("<")

  depth = 0
  split_at = nil
  index = 0
  while index < target.length
    character = target[index]
    if character == "\\"
      index += 2
      next
    elsif character == "("
      depth += 1
    elsif character == ")" && depth.positive?
      depth -= 1
    elsif character.match?(/[ \t]/) && depth.zero?
      split_at = index
      break
    end
    index += 1
  end
  return false unless split_at

  title = target[(split_at + 1)..].strip
  !title.match?(
    /\A(?:"(?:\\.|[^"])*"|'(?:\\.|[^'])*'|\((?:\\.|[^)])*\))\z/
  )
end

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
    has_spaced_target = markdown_link_bodies(line).any? do |body|
      external_link_target_contains_spaces?(body)
    end
    if has_spaced_target
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
