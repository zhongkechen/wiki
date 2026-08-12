# frozen_string_literal: true

require "digest"
require "fileutils"
require "open3"
require "rbconfig"
require "tmpdir"

REPOSITORY_ROOT = File.expand_path("..", __dir__)
ROOT_PAGE_NAMES = %w[
  维基简介
  浙大考博题
  计算机体系结构
  MSP430
  English
  美食
  有趣的小东东
  留言
  SICP的Python实现
].freeze

def assert(condition, message)
  raise message unless condition
end

def digest(path)
  Digest::SHA256.file(path).hexdigest
end

def migrated_files(root)
  ROOT_PAGE_NAMES.flat_map do |page_name|
    page = File.join("old", "#{page_name}.qmd")
    directory_files =
      Dir.chdir(root) do
        Dir[File.join("old", page_name, "**", "*")].select do |path|
          File.file?(path)
        end
      end
    [page, *directory_files]
  end.sort
end

expected_files = migrated_files(REPOSITORY_ROOT)
qmd_files = expected_files.select { |path| path.end_with?(".qmd") }
asset_files = expected_files - qmd_files

assert(qmd_files.length == 13, "Expected 13 QMD pages, found #{qmd_files.length}")
assert(asset_files.length == 51, "Expected 51 attachments, found #{asset_files.length}")

Dir.mktmpdir("check-other-pages-migration") do |temporary_root|
  FileUtils.cp_r(File.join(REPOSITORY_ROOT, "tools"), temporary_root)
  FileUtils.mkdir_p(File.join(temporary_root, "old"))
  ROOT_PAGE_NAMES.each do |page_name|
    FileUtils.cp(
      File.join(REPOSITORY_ROOT, "old", "#{page_name}.qmd"),
      File.join(temporary_root, "old", "#{page_name}.qmd")
    )
    source_directory = File.join(REPOSITORY_ROOT, "old", page_name)
    FileUtils.cp_r(
      source_directory,
      File.join(temporary_root, "old", page_name)
    ) if Dir.exist?(source_directory)
  end

  environment = {
    "MOIN_SOURCE_ROOT" => File.join(temporary_root, "missing-moin-source")
  }
  command = [
    RbConfig.ruby,
    File.join(temporary_root, "tools", "migrate_moin_other_pages.rb")
  ]
  stdout, stderr, status = Open3.capture3(
    environment,
    *command,
    chdir: temporary_root
  )
  assert(status.success?, "Snapshot-only migration failed:\n#{stdout}\n#{stderr}")
  assert(stdout.include?("Converted 13 pages"), "Unexpected page count:\n#{stdout}")
  assert(
    stdout.include?("Copied 51 attachments"),
    "Unexpected attachment count:\n#{stdout}"
  )

  actual_files = migrated_files(temporary_root)
  assert(
    actual_files == expected_files,
    "Snapshot replay produced a different file set"
  )
  expected_files.each do |relative_path|
    expected = File.join(REPOSITORY_ROOT, relative_path)
    actual = File.join(temporary_root, relative_path)
    assert(
      digest(actual) == digest(expected),
      "Snapshot replay changed #{relative_path}"
    )
  end
end

qmd_files.each do |relative_path|
  absolute_path = File.join(REPOSITORY_ROOT, relative_path)
  page = File.read(absolute_path, encoding: "UTF-8")

  assert(!page.include?("attachment:"), "Attachment macro leaked into #{relative_path}")
  assert(!page.include?("{{{"), "Code marker leaked into #{relative_path}")
  assert(!page.include?("#acl"), "MoinMoin ACL leaked into #{relative_path}")
  assert(
    !page.match?(/<<(?:AttachList|Include|PageList|TableOfContents)\b/),
    "MoinMoin macro leaked into #{relative_path}"
  )

  page.scan(/\]\((?:<([^>]+)>|([^)]+))\)/).each do |angle, plain|
    target = angle || plain
    next if target.empty? || target.start_with?("#")
    next if target.match?(%r{\A(?:https?|ftp|mailto):})

    clean_target = target.split(/[?#]/, 2).first
    resolved = File.expand_path(clean_target, File.dirname(absolute_path))
    assert(
      File.exist?(resolved),
      "Broken local link in #{relative_path}: #{target}"
    )
  end
end

homepage = File.read(
  File.join(REPOSITORY_ROOT, "old", "首页.qmd"),
  encoding: "UTF-8"
)
ROOT_PAGE_NAMES.each do |page_name|
  assert(
    homepage.include?("(#{page_name}.qmd)"),
    "Homepage does not link to #{page_name}.qmd"
  )
end

architecture = File.read(
  File.join(REPOSITORY_ROOT, "old", "计算机体系结构.qmd"),
  encoding: "UTF-8"
)
assert(
  architecture.include?("* 体系结构的发展"),
  "Indented architecture outline was not converted to a list"
)
assert(
  architecture.include?("```") &&
    architecture.include?("流水线加速比"),
  "Architecture formula block was not preserved"
)

doctoral_exam = File.read(
  File.join(REPOSITORY_ROOT, "old", "浙大考博题.qmd"),
  encoding: "UTF-8"
)
assert(
  doctoral_exam.include?("```\n进程\t进入队列时间"),
  "Inline-opening exam code block was not repaired"
)

msp430 = File.read(
  File.join(REPOSITORY_ROOT, "old", "MSP430.qmd"),
  encoding: "UTF-8"
)
assert(
  !msp430.include?("ebook 16M.rar"),
  "Unrelated ARM ebook archive was linked from MSP430"
)
assert(
  !File.exist?(
    File.join(
      REPOSITORY_ROOT,
      "old",
      "MSP430",
      "assets",
      "MSP430",
      "ebook 16M.rar"
    )
  ),
  "Unrelated ARM ebook archive was copied"
)

food = File.read(
  File.join(REPOSITORY_ROOT, "old", "美食.qmd"),
  encoding: "UTF-8"
)
assert(food.include?("## 附件"), "Food attachment section is missing")
assert(
  food.include?("川菜烹饪秘诀.pdf"),
  "Food PDF attachments were not preserved"
)

interesting = File.read(
  File.join(REPOSITORY_ROOT, "old", "有趣的小东东.qmd"),
  encoding: "UTF-8"
)
assert(
  interesting.include?("有趣的小东东/Two_Numbers.qmd"),
  "Two_Numbers child link is missing"
)
assert(
  interesting.include?("Lorentz_transform_of_world_line.gif"),
  "External image was not preserved"
)

two_numbers = File.read(
  File.join(REPOSITORY_ROOT, "old", "有趣的小东东", "Two_Numbers.qmd"),
  encoding: "UTF-8"
)
assert(
  two_numbers.include?("已恢复历史版本"),
  "Fallback revision notice is missing"
)
assert(two_numbers.include?("```cpp"), "C++ code fence was not normalized")

comments = File.read(
  File.join(REPOSITORY_ROOT, "old", "留言.qmd"),
  encoding: "UTF-8"
)
assert(comments.include?("## 评论存档"), "Archived comments are missing")
assert(
  comments.include?("[论坛](<ICPC/论坛.qmd>)"),
  "Existing forum page link was not preserved"
)
assert(
  comments.include?("2009-12-29 13:34:42"),
  "Latest archived comment is missing"
)
assert(
  !comments.include?("MoinMoin Powered"),
  "Accidental full-page comment capture was not filtered"
)

sicp = File.read(
  File.join(
    REPOSITORY_ROOT,
    "old",
    "SICP的Python实现",
    "SICP的Python实现1.2.qmd"
  ),
  encoding: "UTF-8"
)
assert(
  sicp.include?("../SICP的Python实现.qmd"),
  "SICP child return link is incorrect"
)
assert(sicp.include?("```python"), "SICP Python code fence was not restored")

english = File.read(
  File.join(REPOSITORY_ROOT, "old", "English.qmd"),
  encoding: "UTF-8"
)
assert(
  english.scan(/^1\. /).length == 3,
  "English section list was not preserved"
)
assert(
  english.scan(/^ {4}1\.$/).length == 30,
  "English question list hierarchy was not preserved"
)
assert(
  english.scan(/^ {8}a\. /).length == 120,
  "English answer choices were not preserved as nested alphabetic lists"
)

english_spam = File.join(
  REPOSITORY_ROOT,
  "old",
  "English",
  "rgalbygejsrpejbcqbsvwainaqusu.qmd"
)
assert(!File.exist?(english_spam), "English spam subpage was migrated")

puts "Other-pages migration snapshot replay passed"
