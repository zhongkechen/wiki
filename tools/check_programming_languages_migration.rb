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

Dir.mktmpdir("check-programming-languages-migration") do |temporary_root|
  FileUtils.cp_r(File.join(REPOSITORY_ROOT, "tools"), temporary_root)
  source_assets = File.join(REPOSITORY_ROOT, "old", "程序设计语言", "assets")
  temporary_assets = File.join(temporary_root, "old", "程序设计语言", "assets")
  FileUtils.mkdir_p(File.dirname(temporary_assets))
  FileUtils.cp_r(source_assets, temporary_assets)

  environment = {
    "MOIN_SOURCE_ROOT" => File.join(temporary_root, "missing-moin-source")
  }
  command = [
    RbConfig.ruby,
    File.join(temporary_root, "tools", "migrate_moin_programming_languages.rb")
  ]
  stdout, stderr, status = Open3.capture3(environment, *command, chdir: temporary_root)
  assert(status.success?, "Snapshot-only migration failed:\n#{stdout}\n#{stderr}")
  assert(stdout.include?("Converted 147 pages"), "Unexpected page count:\n#{stdout}")
  assert(stdout.include?("Copied 36 attachments"), "Unexpected attachment count:\n#{stdout}")

  expected_files = [
    "old/程序设计语言.qmd",
    *Dir.chdir(REPOSITORY_ROOT) do
      Dir["old/程序设计语言/**/*"].select { |path| File.file?(path) }
    end
  ].sort
  actual_files = [
    "old/程序设计语言.qmd",
    *Dir.chdir(temporary_root) do
      Dir["old/程序设计语言/**/*"].select { |path| File.file?(path) }
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
    File.join(temporary_root, "old", "程序设计语言.qmd"),
    encoding: "UTF-8"
  )
  assert(course_page.include?("程序设计语言/Python.qmd"), "Python entry link was lost")
  assert(
    course_page.include?("高级语言程序设计课程/C.qmd"),
    "Existing C migration was not reused"
  )
  assert(course_page.include?("```cpp"), "C++ code language was not normalized")
  assert(course_page.include?("DolphinEducation.exe"), "Root attachment was not preserved")

  cpp_page = File.read(
    File.join(temporary_root, "old", "程序设计语言", "C++.qmd"),
    encoding: "UTF-8"
  )
  assert(cpp_page.include?("C++:bool类型.qmd"), "C++ topic list was not expanded")
  assert(
    cpp_page.include?("../面向对象程序设计课程.qmd"),
    "Existing object-oriented course migration was not reused"
  )
  assert(!cpp_page.include?("Include(C++"), "Include macro names leaked into the topic list")

  python_intro = File.read(
    File.join(temporary_root, "old", "程序设计语言", "Python介绍.qmd"),
    encoding: "UTF-8"
  )
  assert(
    python_intro.include?("Python介绍/Python历史.qmd"),
    "Relative Python introduction pages were not resolved"
  )

  nested_page = File.read(
    File.join(
      temporary_root,
      "old",
      "程序设计语言",
      "SICP的Python实现",
      "SICP的Python实现1.2.qmd"
    ),
    encoding: "UTF-8"
  )
  assert(
    nested_page.include?("../../程序设计语言.qmd"),
    "Nested return link points to the wrong level"
  )
  assert(nested_page.include?("```python"), "SICP Python code fence was not restored")
  assert(!nested_page.include?("{#!python"), "Malformed MoinMoin code marker leaked")

  stl_page = File.read(
    File.join(temporary_root, "old", "程序设计语言", "C++标准模板库.qmd"),
    encoding: "UTF-8"
  )
  assert(
    stl_page.include?("class queue;\n}\n```"),
    "Unclosed queue declaration code block was not repaired"
  )
  assert(!stl_page.include?("{{{"), "MoinMoin code block marker leaked")

  empty_page = File.read(
    File.join(
      temporary_root,
      "old",
      "程序设计语言",
      "STL编程指南",
      "Forward Container.qmd"
    ),
    encoding: "UTF-8"
  )
  assert(
    empty_page.match?(/源页面不可用|暂无正文内容/),
    "Empty historical page did not receive a placeholder"
  )

  qmd_files = Dir[
    File.join(temporary_root, "old", "程序设计语言.qmd"),
    File.join(temporary_root, "old", "程序设计语言", "**", "*.qmd")
  ]
  leaked_macros = qmd_files.select do |path|
    File.read(path, encoding: "UTF-8").match?(/@@MOIN_|<<Include\(|\[\[[^\]]+\]\]/)
  end
  assert(leaked_macros.empty?, "MoinMoin markup leaked into generated pages")
end

puts "Programming languages migration snapshot replay passed"
