# frozen_string_literal: true

require "digest"
require "fileutils"
require "open3"
require "rbconfig"
require "tmpdir"

REPOSITORY_ROOT = File.expand_path("..", __dir__)
TOPIC_PAGES = %w[
  算法专题：动态规划
  算法专题：搜索
  算法专题：贪婪算法
  算法专题：递推求解
].freeze

def assert(condition, message)
  raise message unless condition
end

def file_digest(path)
  Digest::SHA256.file(path).hexdigest
end

Dir.mktmpdir("check-algorithm-migration") do |temporary_root|
  FileUtils.cp_r(File.join(REPOSITORY_ROOT, "tools"), temporary_root)
  FileUtils.mkdir_p(File.join(temporary_root, "old"))
  FileUtils.cp_r(
    File.join(REPOSITORY_ROOT, "old", "ICPC"),
    File.join(temporary_root, "old", "ICPC")
  )

  migration_script = File.join(
    temporary_root,
    "tools",
    "migrate_moin_algorithm.rb"
  )
  assert(File.exist?(migration_script), "Algorithm migration script is missing")

  environment = {
    "MOIN_SOURCE_ROOT" => File.join(temporary_root, "missing-moin-source")
  }
  stdout, stderr, status = Open3.capture3(
    environment,
    RbConfig.ruby,
    migration_script,
    chdir: temporary_root
  )
  assert(status.success?, "Snapshot-only migration failed:\n#{stdout}\n#{stderr}")
  assert(stdout.include?("Converted 1 page"), "Unexpected generated page count:\n#{stdout}")
  assert(
    stdout.include?("Reused 4 existing child pages"),
    "Unexpected reused page count:\n#{stdout}"
  )

  expected = File.join(REPOSITORY_ROOT, "old", "算法.qmd")
  actual = File.join(temporary_root, "old", "算法.qmd")
  assert(File.exist?(actual), "Algorithm index was not generated")
  assert(
    file_digest(actual) == file_digest(expected),
    "Snapshot replay changed old/算法.qmd"
  )

  algorithm_page = File.read(actual, encoding: "UTF-8")
  TOPIC_PAGES.each do |page_name|
    target = "ICPC/#{page_name}.qmd"
    assert(
      algorithm_page.include?(target),
      "Algorithm index does not link to #{target}"
    )
    assert(
      File.exist?(File.join(temporary_root, "old", target)),
      "Reused child page does not exist: #{target}"
    )
  end
  assert(
    !algorithm_page.include?("<<PageList"),
    "Dynamic MoinMoin PageList macro leaked"
  )
  assert(
    algorithm_page.include?(
      "<http://en.wikipedia.org/wiki/Rabin-Karp_string_search_algorithm>"
    ),
    "Bare external URL was not preserved as a clickable link"
  )
  assert(
    !Dir.exist?(File.join(temporary_root, "old", "算法")),
    "Shared algorithm topics were duplicated"
  )
end

puts "Algorithm migration snapshot replay passed"
