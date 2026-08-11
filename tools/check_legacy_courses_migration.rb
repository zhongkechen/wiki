# frozen_string_literal: true

require "digest"
require "fileutils"
require "open3"
require "rbconfig"
require "tmpdir"

REPOSITORY_ROOT = File.expand_path("..", __dir__)
COURSE_NAMES = %w[
  计算机科学导论
  离散数学
  计算机图形学
  算法与数据结构
].freeze

def assert(condition, message)
  raise message unless condition
end

def digest(path)
  Digest::SHA256.file(path).hexdigest
end

def migrated_files(root)
  COURSE_NAMES.flat_map do |course_name|
    [
      File.join("old", "#{course_name}.qmd"),
      *Dir.chdir(root) do
        Dir[File.join("old", course_name, "**", "*")].select do |path|
          File.file?(path)
        end
      end
    ]
  end.sort
end

expected_files = migrated_files(REPOSITORY_ROOT)
assert(!expected_files.empty?, "No migrated files were found")

Dir.mktmpdir("check-legacy-courses-migration") do |temporary_root|
  FileUtils.cp_r(File.join(REPOSITORY_ROOT, "tools"), temporary_root)
  FileUtils.mkdir_p(File.join(temporary_root, "old"))
  COURSE_NAMES.each do |course_name|
    FileUtils.cp(
      File.join(REPOSITORY_ROOT, "old", "#{course_name}.qmd"),
      File.join(temporary_root, "old", "#{course_name}.qmd")
    )
    FileUtils.cp_r(
      File.join(REPOSITORY_ROOT, "old", course_name),
      File.join(temporary_root, "old", course_name)
    )
  end

  environment = {
    "MOIN_SOURCE_ROOT" => File.join(temporary_root, "missing-moin-source")
  }
  command = [
    RbConfig.ruby,
    File.join(temporary_root, "tools", "migrate_moin_legacy_courses.rb")
  ]
  stdout, stderr, status = Open3.capture3(
    environment,
    *command,
    chdir: temporary_root
  )
  assert(status.success?, "Snapshot-only migration failed:\n#{stdout}\n#{stderr}")
  assert(stdout.include?("Converted 63 pages"), "Unexpected page count:\n#{stdout}")
  assert(
    stdout.include?("Copied 69 attachments"),
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

qmd_files = expected_files.select { |path| path.end_with?(".qmd") }
assert(qmd_files.length == 63, "Expected 63 QMD pages, found #{qmd_files.length}")

qmd_files.each do |relative_path|
  absolute_path = File.join(REPOSITORY_ROOT, relative_path)
  page = File.read(absolute_path, encoding: "UTF-8")

  assert(!page.include?("[["), "MoinMoin link leaked into #{relative_path}")
  assert(!page.include?("attachment:"), "Attachment macro leaked into #{relative_path}")
  assert(!page.include?("<<"), "MoinMoin macro leaked into #{relative_path}")
  assert(!page.include?("'''"), "MoinMoin bold markup leaked into #{relative_path}")
  assert(!page.include?("#acl"), "MoinMoin ACL leaked into #{relative_path}")

  page.scan(/\]\((?:<([^>]+)>|([^)]+))\)/).each do |angle, plain|
    target = angle || plain
    next if target.empty? || target.start_with?("#")
    next if target.match?(%r{\A(?:https?|ftp|mailto):})
    next if target.end_with?(".html")

    clean_target = target.split(/[?#]/, 2).first
    resolved = File.expand_path(clean_target, File.dirname(absolute_path))
    assert(
      File.exist?(resolved),
      "Broken local link in #{relative_path}: #{target}"
    )
  end
end

introduction = File.read(
  File.join(REPOSITORY_ROOT, "old", "计算机科学导论.qmd"),
  encoding: "UTF-8"
)
assert(
  introduction.include?("计算机科学导论/计算机导论习题库.qmd"),
  "Introduction page does not link to the migrated exercise index"
)

exercise_index = File.read(
  File.join(
    REPOSITORY_ROOT,
    "old",
    "计算机科学导论",
    "计算机导论习题库.qmd"
  ),
  encoding: "UTF-8"
)
assert(
  exercise_index.include?("第一章 数据存储.qmd"),
  "Exercise index does not link to migrated exercises"
)

graphics = File.read(
  File.join(REPOSITORY_ROOT, "old", "计算机图形学.qmd"),
  encoding: "UTF-8"
)
%w[06.ppt 091.ppt 092.ppt 093.ppt 04.doc 06.doc 11.doc 13.doc 15.doc 36.doc].each do |filename|
  assert(
    graphics.include?("/#{filename}>"),
    "Corrected graphics attachment is missing: #{filename}"
  )
end
assert(
  graphics.include?("/zuoyejieda.ppt>"),
  "Corrected graphics answer attachment is missing"
)

discrete_math = File.read(
  File.join(REPOSITORY_ROOT, "old", "离散数学.qmd"),
  encoding: "UTF-8"
)
assert(
  discrete_math.include?("原附件缺失"),
  "Missing discrete-math attachment is not identified"
)

data_structures = File.read(
  File.join(REPOSITORY_ROOT, "old", "算法与数据结构.qmd"),
  encoding: "UTF-8"
)
assert(
  data_structures.include?("/DSKC05.xls>"),
  "Corrected data-structures attachment is missing"
)

puts "Legacy course migration snapshot replay passed"
