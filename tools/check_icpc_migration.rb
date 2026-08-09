# frozen_string_literal: true

require "digest"
require "fileutils"
require "open3"
require "rbconfig"
require "tmpdir"

REPOSITORY_ROOT = File.expand_path("..", __dir__)

def assert(condition, message)
  raise message unless condition
end

def file_digest(path)
  Digest::SHA256.file(path).hexdigest
end

Dir.mktmpdir("check-icpc-migration") do |temporary_root|
  FileUtils.cp_r(File.join(REPOSITORY_ROOT, "tools"), temporary_root)
  source_assets = File.join(REPOSITORY_ROOT, "old", "ICPC", "assets")
  temporary_assets = File.join(temporary_root, "old", "ICPC", "assets")
  FileUtils.mkdir_p(File.dirname(temporary_assets))
  FileUtils.cp_r(source_assets, temporary_assets)

  environment = {
    "MOIN_SOURCE_ROOT" => File.join(temporary_root, "missing-moin-source")
  }
  command = [
    RbConfig.ruby,
    File.join(temporary_root, "tools", "migrate_moin_icpc.rb")
  ]
  stdout, stderr, status = Open3.capture3(environment, *command, chdir: temporary_root)
  assert(status.success?, "Snapshot-only migration failed:\n#{stdout}\n#{stderr}")
  assert(stdout.include?("Converted 203 pages"), "Unexpected page count:\n#{stdout}")
  assert(stdout.include?("Copied 41 attachments"), "Unexpected attachment count:\n#{stdout}")

  expected_files = [
    "old/ICPC.qmd",
    *Dir.chdir(REPOSITORY_ROOT) do
      Dir["old/ICPC/**/*"].select { |path| File.file?(path) }
    end
  ].sort
  actual_files = [
    "old/ICPC.qmd",
    *Dir.chdir(temporary_root) do
      Dir["old/ICPC/**/*"].select { |path| File.file?(path) }
    end
  ].sort
  assert(actual_files == expected_files, "Snapshot replay produced a different file set")

  expected_files.each do |relative_path|
    expected = File.join(REPOSITORY_ROOT, relative_path)
    actual = File.join(temporary_root, relative_path)
    assert(
      file_digest(actual) == file_digest(expected),
      "Snapshot replay changed #{relative_path}"
    )
  end

  course_page = File.read(
    File.join(temporary_root, "old", "ICPC.qmd"),
    encoding: "UTF-8"
  )
  assert(course_page.include?("算法专题：动态规划.qmd"), "PageList content was not expanded")
  assert(course_page.include?("C++集成开发环境.qmd"), "Shared page link was not preserved")
  assert(!course_page.match?(/<<(?:PageList|RandomQuote)/), "Dynamic MoinMoin macro leaked")

  code_page = File.read(
    File.join(temporary_root, "old", "ICPC", "hdu1072 参考答案.qmd"),
    encoding: "UTF-8"
  )
  assert(code_page.include?("```cpp"), "C++ code block language was not normalized")
  assert(!code_page.include?("#!cplusplus"), "MoinMoin code directive leaked")

  placeholder_page = File.read(
    File.join(temporary_root, "old", "ICPC", "hdu1024 参考答案.qmd"),
    encoding: "UTF-8"
  )
  assert(placeholder_page.include?("源页面不可用"), "Missing revision placeholder was lost")
end

puts "ICPC migration snapshot replay passed"
