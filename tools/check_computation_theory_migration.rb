# frozen_string_literal: true

require "digest"
require "fileutils"
require "open3"
require "rbconfig"
require "tmpdir"

REPOSITORY_ROOT = File.expand_path("..", __dir__)
CHILD_PAGE_NAMES = %w[
  集合、关系和语言
  有穷自动机
  上下文无关语言
  图灵机
  不可判定性
  计算复杂性
  NP完全性
].freeze

def assert(condition, message)
  raise message unless condition
end

def file_digest(path)
  Digest::SHA256.file(path).hexdigest
end

Dir.mktmpdir("check-computation-theory-migration") do |temporary_root|
  FileUtils.cp_r(File.join(REPOSITORY_ROOT, "tools"), temporary_root)
  FileUtils.mkdir_p(File.join(temporary_root, "old"))

  environment = {
    "MOIN_SOURCE_ROOT" => File.join(temporary_root, "missing-moin-source")
  }
  command = [
    RbConfig.ruby,
    File.join(
      temporary_root,
      "tools",
      "migrate_moin_computation_theory.rb"
    )
  ]
  stdout, stderr, status = Open3.capture3(
    environment,
    *command,
    chdir: temporary_root
  )
  assert(status.success?, "Snapshot-only migration failed:\n#{stdout}\n#{stderr}")
  assert(stdout.include?("Converted 8 pages"), "Unexpected page count:\n#{stdout}")
  assert(
    stdout.include?("Copied 0 attachments"),
    "Unexpected attachment handling:\n#{stdout}"
  )

  expected_files = [
    "old/计算理论.qmd",
    *Dir.chdir(REPOSITORY_ROOT) do
      Dir["old/计算理论/**/*"].select { |path| File.file?(path) }
    end
  ].sort
  actual_files = [
    "old/计算理论.qmd",
    *Dir.chdir(temporary_root) do
      Dir["old/计算理论/**/*"].select { |path| File.file?(path) }
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
    File.join(temporary_root, "old", "计算理论.qmd"),
    encoding: "UTF-8"
  )
  CHILD_PAGE_NAMES.each do |page_name|
    target = "计算理论/#{page_name}.qmd"
    assert(
      course_page.include?(target),
      "Computation theory index does not link to #{target}"
    )
  end

  finite_automata = File.read(
    File.join(temporary_root, "old", "计算理论", "有穷自动机.qmd"),
    encoding: "UTF-8"
  )
  assert(
    finite_automata.include?("**确定型有穷自动机**"),
    "MoinMoin bold markup was not converted"
  )
  assert(
    finite_automata.include?('$\asymp_L$'),
    "Legacy entity and subscript markup was not converted"
  )

  turing_machine = File.read(
    File.join(temporary_root, "old", "计算理论", "图灵机.qmd"),
    encoding: "UTF-8"
  )
  assert(
    turing_machine.include?("    1. 对所有"),
    "Nested ordered lists were not preserved"
  )

  undecidability = File.read(
    File.join(temporary_root, "old", "计算理论", "不可判定性.qmd"),
    encoding: "UTF-8"
  )
  assert(
    undecidability.include?('$H=\lbrace'),
    "LaTeX macro was not converted to native math"
  )

  expected_files.each do |relative_path|
    page = File.read(File.join(temporary_root, relative_path), encoding: "UTF-8")
    assert(!page.include?("#format inline_latex"), "Format pragma leaked into #{relative_path}")
    assert(!page.include?("<<latex"), "LaTeX macro leaked into #{relative_path}")
    assert(!page.include?("[["), "MoinMoin link leaked into #{relative_path}")
    assert(!page.include?("'''"), "MoinMoin bold markup leaked into #{relative_path}")
  end
  assert(
    !Dir.exist?(File.join(temporary_root, "old", "计算理论", "assets")),
    "Unreferenced legacy formula images were copied"
  )
end

puts "Computation theory migration snapshot replay passed"
