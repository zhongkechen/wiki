# frozen_string_literal: true

require "timeout"
require_relative "check_old_site"

def assert_equal(expected, actual, description)
  return if expected == actual

  abort "#{description}: expected #{expected.inspect}, got #{actual.inspect}"
end

valid_targets = [
  'https://example.com "title"',
  'https://example.com "escaped \\" quote"',
  'https://example.com "terminal \\"',
  "https://example.com 'title'",
  "https://example.com 'escaped \\' quote'",
  'https://example.com (title)',
  'https://example.com (escaped \\) parenthesis)',
  'https://example.com (escaped \\中文)',
  'https://example.com ""',
  "https://example.com ''",
  "https://example.com ()"
]
valid_targets.each do |target|
  assert_equal(
    false,
    external_link_target_contains_spaces?(target),
    "valid Markdown title was rejected"
  )
end

invalid_targets = [
  "https://example.com unquoted title",
  'https://example.com "unterminated',
  "https://example.com 'unterminated",
  "https://example.com (unterminated",
  'https://example.com "title" trailing'
]
invalid_targets.each do |target|
  assert_equal(
    true,
    external_link_target_contains_spaces?(target),
    "invalid Markdown title was accepted"
  )
end

adversarial_titles = {
  '"' => "\\!" * 100_000,
  "'" => "\\&" * 100_000,
  "(" => "\\(" * 100_000
}
Timeout.timeout(1) do
  adversarial_titles.each do |opening, content|
    assert_equal(
      true,
      external_link_target_contains_spaces?(
        "https://example.com #{opening}#{content}invalid"
      ),
      "adversarial Markdown title was accepted"
    )
  end
end

puts "Old-site link-title security checks passed"
