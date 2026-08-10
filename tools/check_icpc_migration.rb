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
  assert(course_page.include?("> 很多题目都是英文的"), "Random quote lost blockquote markup")
  assert(!course_page.match?(/<<(?:PageList|RandomQuote)/), "Dynamic MoinMoin macro leaked")

  algorithm_topics = %w[
    算法专题：动态规划
    算法专题：搜索
    算法专题：贪婪算法
    算法专题：递推求解
  ]
  algorithm_topics.each do |page_name|
    topic_page = File.read(
      File.join(temporary_root, "old", "ICPC", "#{page_name}.qmd"),
      encoding: "UTF-8"
    )
    assert(
      topic_page.include?("[返回“算法”](../算法.qmd)"),
      "#{page_name} does not link back to the algorithm index"
    )
    assert(
      topic_page.include?("[返回“大学生程序设计竞赛”](../ICPC.qmd)"),
      "#{page_name} lost its ICPC return link"
    )
  end

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

  matrix_page = File.read(
    File.join(temporary_root, "old", "ICPC", "zju1094.qmd"),
    encoding: "UTF-8"
  )
  assert(matrix_page.include?("A\\*B\\*C"), "Literal multiplication became Markdown")
  assert(matrix_page.include?("&lt;EOF&gt;"), "Literal angle-bracket text became HTML")
  assert(matrix_page.include?("SecondPart"), "Empty inline literal escape was not removed")

  html_problem_page = File.read(
    File.join(temporary_root, "old", "ICPC", "zju1099.qmd"),
    encoding: "UTF-8"
  )
  assert(html_problem_page.include?("&lt;br&gt;"), "Literal HTML tag was not escaped")

  judge_page = File.read(
    File.join(temporary_root, "old", "ICPC", "在线判题系统.qmd"),
    encoding: "UTF-8"
  )
  assert(
    judge_page.include?("换行符为\\\\r\\\\n，而判题程序认为换行符为\\\\n"),
    "Literal backslashes were not escaped"
  )

  beginner_page = File.read(
    File.join(temporary_root, "old", "ICPC", "ACM新手入门.qmd"),
    encoding: "UTF-8"
  )
  assert(beginner_page.include?("    1. 打开网址"), "Alphabetic sublist was not normalized")

  training_page = File.read(
    File.join(temporary_root, "old", "ICPC", "2008年春培训计划.qmd"),
    encoding: "UTF-8"
  )
  assert(
    training_page.include?("[BFS及其应用](http://"),
    "Legacy external link syntax was not converted"
  )
  assert(
    !training_page.match?(/\]\(http[^)]+\)\(http/),
    "Generated external link was converted twice"
  )

  history_page = File.read(
    File.join(temporary_root, "old", "ICPC", "温州大学ACM_ICPC训练队历史.qmd"),
    encoding: "UTF-8"
  )
  assert(
    history_page.match?(/\|  \|  \|  \|  \|\n\| --- \| --- \| --- \| --- \|\n\| 曹高挺 /),
    "Headerless table promoted its first data row"
  )

  broken_fence_pages = Dir[
    File.join(temporary_root, "old", "ICPC", "*.qmd")
  ].select do |path|
    File.read(path, encoding: "UTF-8").match?(/```\n-{3,}\n```/)
  end
  assert(broken_fence_pages.empty?, "Horizontal rule remained adjacent to code fences")
end

puts "ICPC migration snapshot replay passed"
