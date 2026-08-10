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

  deque_page = File.read(
    File.join(
      temporary_root,
      "old",
      "程序设计语言",
      "STL编程指南",
      "deque.qmd"
    ),
    encoding: "UTF-8"
  )
  assert(!deque_page.match?(/<html\b/i), "Outer legacy HTML wrapper leaked")
  assert(
    deque_page.include?('href="Random Access Container.html"'),
    "Legacy SGI page links were not rewritten"
  )
  container_page = File.read(
    File.join(
      temporary_root,
      "old",
      "程序设计语言",
      "STL编程指南",
      "Container.qmd"
    ),
    encoding: "UTF-8"
  )
  legacy_stl_targets = %w[
    Vector.html
    List.html
    Slist.html
    Deque.html
    ForwardContainer.html
    RandomAccessContainer.html
    FrontInsertionSequence.html
    BackInsertionSequence.html
    ReversibleContainer.html
  ]
  legacy_stl_targets.each do |legacy_target|
    assert(
      [container_page, deque_page].none? do |page|
        page.include?("href=\"#{legacy_target}\"")
      end,
      "Legacy SGI link #{legacy_target} was not rewritten"
    )
  end
  assert(
    !deque_page.match?(
      /src\s*=\s*"(?:\/images\/common\/sgilogo_small\.gif|containers\.gif|type\.gif)"/i
    ),
    "Unavailable legacy images were retained"
  )

  pil_page = File.read(
    File.join(
      temporary_root,
      "old",
      "程序设计语言",
      "PythonImageLibrary中文手册.qmd"
    ),
    encoding: "UTF-8"
  )
  assert(
    pil_page.include?("[getbands](#image-getbands-method)"),
    "Legacy PIL method link was not mapped to the merged page"
  )
  {
    "[mode](#image-mode-attribute)" => "PIL mode link",
    "[size](#image-size-attribute)" => "PIL size link",
    "[info](#image-info-attribute)" => "PIL info link",
    "[图像文件格式](#pil-image-formats)" => "PIL formats link",
    "[编写自己的文件解码器](#pil-custom-decoder)" => "PIL decoder link",
    "[ImageChops](#imagechops-offset)" => "PIL ImageChops link",
    "#### open {#image-open-function}" => "PIL open fragment",
    "#### getbands {#image-getbands-method}" => "PIL getbands fragment",
    "#### mode {#image-mode-attribute}" => "PIL mode fragment",
    "#### size {#image-size-attribute}" => "PIL size fragment",
    "#### info {#image-info-attribute}" => "PIL info fragment",
    "#### offset {#imagechops-offset}" => "PIL ImageChops fragment",
    "### 图像文件格式 {#pil-image-formats}" => "PIL formats fragment",
    "### 编写自己的文件解码器 {#pil-custom-decoder}" => "PIL decoder fragment"
  }.each do |expected, description|
    assert(pil_page.include?(expected), "#{description} was not preserved")
  end
  assert(
    !pil_page.match?(/\[(?:image|formats|decoder|imagechops)\.htm/i),
    "Legacy PIL handbook link syntax leaked"
  )
  assert(
    pil_page.include?("**从图像中拷贝一块子矩形区域**"),
    "Malformed PIL bold marker was not repaired"
  )
  assert(
    pil_page.include?("**im.info** =&gt; dictionary"),
    "PIL emphasis conversion consumed content across lines"
  )
  assert(
    !pil_page.match?(/(?<!\S)\*\*[ \t]+\S/),
    "PIL emphasis retained leading whitespace inside Markdown delimiters"
  )

  cpp_basics = File.read(
    File.join(
      temporary_root,
      "old",
      "程序设计语言",
      "C++编程基础.qmd"
    ),
    encoding: "UTF-8"
  )
  assert(
    !cpp_basics.include?("#pragma section-numbers"),
    "MoinMoin section-number pragma leaked"
  )
  assert(
    cpp_basics.include?("number-sections: true"),
    "MoinMoin section numbering was not mapped to Quarto"
  )
  cpp_procedural = File.read(
    File.join(
      temporary_root,
      "old",
      "程序设计语言",
      "C++面向过程程序设计.qmd"
    ),
    encoding: "UTF-8"
  )
  assert(
    !cpp_procedural.include?("#pragma section-numbers"),
    "Second MoinMoin section-number pragma leaked"
  )
  assert(
    cpp_procedural.include?("number-sections: true"),
    "Second MoinMoin section-number pragma was not mapped to Quarto"
  )

  django_page = File.read(
    File.join(temporary_root, "old", "程序设计语言", "Django.qmd"),
    encoding: "UTF-8"
  )
  assert(django_page.include?("<iframe "), "Django iframe was lost")
  assert(!django_page.include?("```raw"), "Django raw HTML was rendered as code")
  assert(
    django_page.include?('src="https://docs.google.com/'),
    "Django iframe retained a mixed-content URL"
  )

  vector_page = File.read(
    File.join(
      temporary_root,
      "old",
      "程序设计语言",
      "STL编程指南",
      "vector.qmd"
    ),
    encoding: "UTF-8"
  )
  [vector_page, deque_page].each do |page|
    assert(
      !page.include?("operator[]("),
      "C++ operator[] signature was left open to Markdown link parsing"
    )
    assert(
      page.include?("operator&#91;&#93;("),
      "C++ operator[] signature was not protected from Markdown link parsing"
    )
  end

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
