# frozen_string_literal: true

require "digest"
require "fileutils"
require "open3"
require "rbconfig"
require "tmpdir"

require_relative "moin_additional_pages"

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
  C++集成开发环境
  TCPL
  毕业设计
  cchuang
  ymc
  lzhongyue
  其他历史页面
].freeze
HOMEPAGE_PAGE_NAMES = %w[
  维基简介
  浙大考博题
  计算机体系结构
  MSP430
  English
  美食
  有趣的小东东
  留言
  SICP的Python实现
  毕业设计
  cchuang
  ymc
  lzhongyue
  其他历史页面
].freeze

def assert(condition, message)
  raise message unless condition
end

def digest(path)
  Digest::SHA256.file(path).hexdigest
end

def additional_output_name(name)
  MOIN_ADDITIONAL_PAGE_OUTPUT_NAMES.fetch(name, File.basename(name).delete("<>"))
end

def additional_page(name)
  File.read(
    File.join(
      REPOSITORY_ROOT,
      "old",
      "其他历史页面",
      "#{additional_output_name(name)}.qmd"
    ),
    encoding: "UTF-8"
  )
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

assert(qmd_files.length == 372, "Expected 372 QMD pages, found #{qmd_files.length}")
assert(asset_files.length == 171, "Expected 171 attachments, found #{asset_files.length}")
assert(
  MOIN_ADDITIONAL_PAGE_NAMES.length == 117,
  "Expected 117 additional source pages"
)
assert(
  MOIN_ADDITIONAL_PAGE_NAMES.uniq.length == MOIN_ADDITIONAL_PAGE_NAMES.length,
  "Additional source page list contains duplicates"
)

archive_index = File.read(
  File.join(REPOSITORY_ROOT, "old", "其他历史页面.qmd"),
  encoding: "UTF-8"
)
MOIN_ADDITIONAL_PAGE_GROUPS.each do |group_name, page_names|
  assert(
    archive_index.include?("## #{group_name}"),
    "Archive index is missing the #{group_name} group"
  )
  page_names.each do |page_name|
    basename = additional_output_name(page_name)
    relative_path = File.join("old", "其他历史页面", "#{basename}.qmd")
    assert(
      File.file?(File.join(REPOSITORY_ROOT, relative_path)),
      "Missing additional archive page #{relative_path}"
    )
    assert(
      archive_index.include?("<其他历史页面/#{basename}.qmd>"),
      "Archive index does not link to #{relative_path}"
    )
  end
end

%w[MacOSX vmware 通讯录].each do |excluded_name|
  path = File.join(
    REPOSITORY_ROOT,
    "old",
    "其他历史页面",
    "#{excluded_name}.qmd"
  )
  assert(!File.exist?(path), "Excluded page was published: #{excluded_name}")
end
assert(
  !File.exist?(
    File.join(REPOSITORY_ROOT, "old", "其他历史页面", "MyOwn.qmd")
  ),
  "Private personal notes were published"
)

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
  assert(stdout.include?("Converted 372 pages"), "Unexpected page count:\n#{stdout}")
  assert(
    stdout.include?("Copied 171 attachments"),
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
  assert(
    !page.include?("<<FootNote"),
    "MoinMoin footnote macro leaked into #{relative_path}"
  )
  assert(
    !page.match?(/^```(?:wiki|raw)\s*$/),
    "MoinMoin processor was converted to a code block in #{relative_path}"
  )

  linkable_page = page.gsub(
    /^[ \t]*(`{3,}|~{3,})[^\n]*\n.*?^[ \t]*\1[ \t]*$/m,
    ""
  )
  linkable_page.scan(/\]\((?:<([^>]+)>|([^)]+))\)/).each do |angle, plain|
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

cpp_exercises = additional_page("C++更多练习")
assert(
  !cpp_exercises.include?("TableOfContents"),
  "Legacy table-of-contents macro leaked into C++ exercises"
)

common_operating_systems = additional_page("常见操作系统")
assert(
  common_operating_systems.include?("#### Linux的不足"),
  "Linux limitations section was not converted to a heading"
)
assert(
  !common_operating_systems.include?("* Linux的不足"),
  "Linux limitations section was converted to a list item"
)
assert(
  cpp_exercises.scan(/^ {4}\* [A-D]\. /).length == 80,
  "C++ exercise choices were not preserved as nested lists"
)

android = additional_page("Android")
assert(
  android.include?("::: {.callout-warning}") &&
    android.include?(
      "[为什么中国Android应用需要如此多的权限]" \
        "(https://www.solidot.org/story?sid=34681)"
    ),
  "Android warning block was not converted with its link"
)

telegram = additional_page("Telegram")
%w[note warning tip].each do |callout_type|
  assert(
    telegram.include?("::: {.callout-#{callout_type}}"),
    "Telegram #{callout_type} block was not converted"
  )
end
assert(
  telegram.include?(
    "![why telegram](<assets/Telegram/why_telegram.png>){width=90%}"
  ),
  "Telegram image width was not preserved"
)

full_openwrt = additional_page("基于OpenWrt路由器的全自动翻墙方案")
assert(
  full_openwrt.include?("[科学上网](<../../wiki/科学上网.md>)") &&
    full_openwrt.include?(
      "[xtables-addons源码]" \
        "(http://sourceforge.net/projects/xtables-addons/files/)"
    ),
  "Full OpenWrt page links were not repaired"
)

partial_openwrt = additional_page("基于OpenWrt路由器的（不完全）自动翻墙方案")
assert(
  partial_openwrt.include?("~~iptables u32或string模块过滤错误的DNS结果~~") &&
    partial_openwrt.include?("[科学上网](<../../wiki/科学上网.md>)"),
  "Partial OpenWrt page formatting was not converted"
)

dns = additional_page("如何防止DNS污染和劫持")
assert(
  dns.include?("::: {.callout-warning}") &&
    dns.include?("[科学上网](<../../wiki/科学上网.md>)"),
  "DNS warning block was not converted with its link"
)

ajax = additional_page("AJAX综述")
assert(
  ajax.include?("[Google Suggest](http://www.google.com/webhp?complete=1&hl=en)") &&
    ajax.include?(
      "![ajax-fig1.png]" \
        "(http://www.adaptivepath.com/images/publications/essays/ajax-fig1.png)"
    ),
  "Legacy AJAX links and images were not converted"
)

photos = additional_page("2007年南京比赛高挺拍的照片")
assert(
  !photos.include?("AttachList") &&
    photos.scan(/^\* \[.+\.jpg\]\(<assets\//).length == 43,
  "Photo attachment list was not expanded"
)

python_software = additional_page("Python相关软件")
%w[PythonLdap PyGtk Django Pygame].each do |page_name|
  assert(
    python_software.include?("../程序设计语言/#{page_name}.qmd"),
    "Python software page lost its #{page_name} link"
  )
end

svn = additional_page("svn")
assert(
  svn.include?("[apache2](<../Linux/apache2.qmd>)"),
  "SVN page lost its apache2 link"
)

linux_applications = additional_page("Linux应用程序")
%w[Emacs VI TeX排版].each do |page_name|
  assert(
    linux_applications.include?("../Linux/#{page_name}.qmd"),
    "Linux applications page lost its #{page_name} link"
  )
end

development_tools = additional_page("开发工具")
assert(
  development_tools.include?("<iframe ") &&
    !development_tools.include?("```raw"),
  "Raw iframe was not preserved as HTML"
)

windows_mobile = additional_page("WindowsMobile")
assert(
  windows_mobile.scan(/\{width=350\}/).length == 2,
  "Windows Mobile image widths were not preserved"
)

ios = additional_page("iOS")
assert(
  ios.include?("[Apple Platform Security Guide]") &&
    ios.include?("[Carcassonne]"),
  "iOS reference links were not migrated"
)

development_efficiency = additional_page("开发效率")
assert(
  development_efficiency.include?("### 个人效率") &&
    development_efficiency.include?("### 团队效率") &&
    development_efficiency.include?("[What is OKR]"),
  "Development efficiency sections were not migrated"
)

course_results = additional_page("课程成绩")
assert(
  course_results.include?("学生成绩属于个人隐私"),
  "Course result privacy notice was not migrated"
)

career_summary = additional_page("总结")
assert(
  career_summary.include?("2004年初为教师") &&
    career_summary.include?("四、努力方向"),
  "Career summary content was not migrated"
)

nds_links = additional_page("nds")
assert(
  nds_links.include?("[nds非官方FAQ](<nds非官方FAQ.qmd>)") &&
    nds_links.include?("[flashme](http://ds.gcdev.com/dsfirmware/)") &&
    nds_links.scan(%r{^\* \[.+\.jpg\]\(<assets/nds/}).length == 11,
  "Legacy NDS links were not migrated"
)

assert(
  additional_page("健康").include?("[HP Ergonomics]"),
  "Health reference was not migrated"
)
assert(
  additional_page("动漫").include?("死亡笔记"),
  "Anime note was not migrated"
)
assert(
  additional_page("热门新技术").include?("Open Document"),
  "Emerging technology links were not migrated"
)
assert(
  additional_page("相册").include?("picasaweb.google.com/chen.zhongke"),
  "Photo album links were not migrated"
)

school_files = additional_page("学校文件")
assert(
  school_files.include?(
    '<iframe src="https://calendar.google.com/calendar/embed?'
  ) &&
    !school_files.include?("```html"),
  "School calendar iframe was not preserved as secure HTML"
)

operating_system = additional_page("操作系统")
assert(
  operating_system.include?("## 概述") &&
    operating_system.include?("## 进程管理") &&
    operating_system.include?("### Linux系统"),
  "Operating system outline was not migrated"
)

television_streams = additional_page("网络电视地址")
assert(
  television_streams.include?("## 中央台") &&
    television_streams.include?("CCTV-1 综合频道") &&
    television_streams.include?("### 广播地址") &&
    television_streams.include?("#### 浙江丶江苏"),
  "Legacy television stream archive was not migrated"
)

debian_apache = additional_page("debianapache2")
assert(
  debian_apache.scan("[[:space:]]").length == 4 &&
    !debian_apache.include?("delete:space:+from"),
  "Apache POSIX character classes were not preserved"
)
debian_apache_prose = debian_apache.gsub(
  /^```[^\n]*\n.*?^```[ \t]*$/m,
  ""
)
assert(
  debian_apache.include?("```text\n# a2enmod  userdir") &&
    debian_apache.include?("```text\n# apache2 -l") &&
    debian_apache.include?(
      "```text\n==== mod-security.conf 文件内容开始===="
    ) &&
    !debian_apache_prose.match?(/^#\s/),
  "Apache commands or configuration comments were rendered as headings"
)

software_prices = additional_page("常见软件价格")
assert(
  software_prices.include?("| 软件名称 | 价格 | 官方网址 |") &&
    software_prices.include?("Adobe Photoshop CS3") &&
    software_prices.include?("Microsoft Windows xp pro"),
  "Software price table was not migrated"
)
assert(
  additional_page("MS-Windows").include?(
    "[常见软件价格](<常见软件价格.qmd>)"
  ),
  "MS-Windows page does not link to the migrated software price table"
)

assert(
  additional_page("万维网").include?("HTML、CSS和其他"),
  "Malformed CSS link was not repaired"
)
assert(
  additional_page("程序").include?("一组指示计算机每一步动作的指令"),
  "Malformed instruction link was not repaired"
)

homepage = File.read(
  File.join(REPOSITORY_ROOT, "old", "首页.qmd"),
  encoding: "UTF-8"
)
HOMEPAGE_PAGE_NAMES.each do |page_name|
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

development_environment = File.read(
  File.join(REPOSITORY_ROOT, "old", "C++集成开发环境.qmd"),
  encoding: "UTF-8"
)
assert(
  development_environment.include?(
    "C++集成开发环境/VC++2003.qmd"
  ),
  "C++ development environment child pages were not migrated"
)

mingw = File.read(
  File.join(REPOSITORY_ROOT, "old", "C++集成开发环境", "MinGW.qmd"),
  encoding: "UTF-8"
)
assert(
  mingw.include?("源页面不可用"),
  "Unreadable MinGW source page is missing its warning"
)

tcpl = File.read(
  File.join(REPOSITORY_ROOT, "old", "TCPL.qmd"),
  encoding: "UTF-8"
)
assert(
  tcpl.include?("TCPL/C_Summary_of_Changes.qmd"),
  "TCPL chapter index was not expanded"
)
assert(
  !tcpl.include?("#pragma section-numbers"),
  "TCPL section numbering pragma leaked into the generated page"
)
tcpl_pages = Dir[File.join(REPOSITORY_ROOT, "old", "TCPL", "*.qmd")]
assert(
  tcpl_pages.length == 221,
  "Expected 221 valid TCPL child pages, found #{tcpl_pages.length}"
)

tcpl_reference_manual = File.read(
  File.join(REPOSITORY_ROOT, "old", "TCPL", "A_Reference_Manual.qmd"),
  encoding: "UTF-8"
)
assert(
  tcpl_reference_manual.include?("[A.1 Introduction](<A.01_Introduction.qmd>)"),
  "TCPL reference manual child index was not expanded"
)

tcpl_introduction = File.read(
  File.join(REPOSITORY_ROOT, "old", "TCPL", "A.01_Introduction.qmd"),
  encoding: "UTF-8"
)
assert(
  tcpl_introduction.include?("This manual describes the C language"),
  "TCPL child page content was not migrated"
)

tcpl_library = File.read(
  File.join(REPOSITORY_ROOT, "old", "TCPL", "B_Standard_Library.qmd"),
  encoding: "UTF-8"
)
assert(
  tcpl_library.include?(
    "[B.1 Input and Output: &lt;stdio.h&gt;]" \
      "(<B.01_Input_and_Output:_stdio.h.qmd>)"
  ),
  "TCPL standard-library links with header names were not preserved"
)

tcpl_spam = File.join(
  REPOSITORY_ROOT,
  "old",
  "TCPL",
  "ugczovkjkeluzdbrjicfhozvfajh.qmd"
)
assert(!File.exist?(tcpl_spam), "TCPL spam subpage was migrated")

graduation = File.read(
  File.join(REPOSITORY_ROOT, "old", "毕业设计.qmd"),
  encoding: "UTF-8"
)
assert(
  graduation.include?("毕业设计/在线判题题库建设.qmd"),
  "Graduation project pages were not migrated"
)

english_spam = File.join(
  REPOSITORY_ROOT,
  "old",
  "English",
  "rgalbygejsrpejbcqbsvwainaqusu.qmd"
)
assert(!File.exist?(english_spam), "English spam subpage was migrated")

puts "Other-pages migration snapshot replay passed"
