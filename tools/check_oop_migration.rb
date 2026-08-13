# frozen_string_literal: true

require "digest"
require "fileutils"
require "open3"
require "rbconfig"
require "tmpdir"

REPOSITORY_ROOT = File.expand_path("..", __dir__)
COURSE_NAME = "面向对象程序设计课程"

def assert(condition, message)
  raise message unless condition
end

def digest(path)
  Digest::SHA256.file(path).hexdigest
end

def migrated_files(root)
  [
    File.join("old", "#{COURSE_NAME}.qmd"),
    *Dir.chdir(root) do
      Dir[File.join("old", COURSE_NAME, "**", "*")].select do |path|
        File.file?(path)
      end
    end
  ].sort
end

expected_files = migrated_files(REPOSITORY_ROOT)
qmd_files = expected_files.select { |path| path.end_with?(".qmd") }
asset_files = expected_files - qmd_files

assert(qmd_files.length == 41, "Expected 41 QMD pages, found #{qmd_files.length}")
assert(asset_files.length == 38, "Expected 38 attachments, found #{asset_files.length}")

Dir.mktmpdir("check-oop-migration") do |temporary_root|
  FileUtils.cp_r(File.join(REPOSITORY_ROOT, "tools"), temporary_root)
  FileUtils.mkdir_p(File.join(temporary_root, "old"))
  FileUtils.cp(
    File.join(REPOSITORY_ROOT, "old", "#{COURSE_NAME}.qmd"),
    File.join(temporary_root, "old", "#{COURSE_NAME}.qmd")
  )
  FileUtils.cp_r(
    File.join(REPOSITORY_ROOT, "old", COURSE_NAME),
    File.join(temporary_root, "old", COURSE_NAME)
  )

  environment = {
    "MOIN_SOURCE_ROOT" => File.join(temporary_root, "missing-moin-source")
  }
  command = [
    RbConfig.ruby,
    File.join(temporary_root, "tools", "migrate_moin_oop.rb")
  ]
  stdout, stderr, status = Open3.capture3(
    environment,
    *command,
    chdir: temporary_root
  )
  assert(status.success?, "Snapshot-only migration failed:\n#{stdout}\n#{stderr}")
  assert(stdout.include?("Converted 41 pages"), "Unexpected page count:\n#{stdout}")
  assert(
    stdout.include?("Copied 38 attachments"),
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

  assert(!page.include?("[["), "MoinMoin link leaked into #{relative_path}")
  assert(!page.include?("attachment:"), "Attachment macro leaked into #{relative_path}")
  assert(!page.include?("{{{"), "Code marker leaked into #{relative_path}")
  assert(!page.include?("#acl"), "MoinMoin ACL leaked into #{relative_path}")

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

course = File.read(
  File.join(REPOSITORY_ROOT, "old", "#{COURSE_NAME}.qmd"),
  encoding: "UTF-8"
)
assert(
  course.include?("程序设计语言/C++.qmd"),
  "Existing C++ migration was not reused"
)
assert(
  course.include?("#{COURSE_NAME}/C++实验.qmd"),
  "C++ exercise pages were not migrated"
)

experiment = File.read(
  File.join(REPOSITORY_ROOT, "old", COURSE_NAME, "C++实验.qmd"),
  encoding: "UTF-8"
)
assert(
  experiment.include?("../C++集成开发环境.qmd"),
  "Shared development environment page was not reused"
)
assert(
  experiment.include?("05瓯信算面向对象实验.qmd"),
  "Exercise child pages were not migrated"
)

guide = File.read(
  File.join(
    REPOSITORY_ROOT,
    "old",
    COURSE_NAME,
    "面向对象程序设计课程设计指导书.qmd"
  ),
  encoding: "UTF-8"
)
assert(
  guide.include?("C++课程设计.qmd"),
  "Course design guide still points to the missing legacy page"
)

puts "Object-oriented programming migration snapshot replay passed"
