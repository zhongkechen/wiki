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

Dir.mktmpdir("check-linux-migration") do |temporary_root|
  FileUtils.cp_r(File.join(REPOSITORY_ROOT, "tools"), temporary_root)
  FileUtils.mkdir_p(File.join(temporary_root, "old"))

  environment = {
    "MOIN_SOURCE_ROOT" => File.join(temporary_root, "missing-moin-source")
  }
  command = [
    RbConfig.ruby,
    File.join(temporary_root, "tools", "migrate_moin_linux.rb")
  ]
  stdout, stderr, status = Open3.capture3(environment, *command, chdir: temporary_root)
  assert(status.success?, "Snapshot-only migration failed:\n#{stdout}\n#{stderr}")
  assert(stdout.include?("Converted 39 pages"), "Unexpected page count:\n#{stdout}")
  assert(stdout.include?("Copied 97 attachments"), "Attachments were not reproduced:\n#{stdout}")

  expected_files = [
    "old/Linux.qmd",
    *Dir.chdir(REPOSITORY_ROOT) do
      Dir["old/Linux/**/*"].select { |path| File.file?(path) }
    end
  ].sort
  actual_files = [
    "old/Linux.qmd",
    *Dir.chdir(temporary_root) do
      Dir["old/Linux/**/*"].select { |path| File.file?(path) }
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

  restored_page = File.read(
    File.join(temporary_root, "old", "Linux", "什么是Linux.qmd"),
    encoding: "UTF-8"
  )
  assert(restored_page.include?("Linux是一个操作系统"), "Historical Linux article was not restored")
  assert(!restored_page.include?("源页面不可用"), "Historical Linux article still uses a placeholder")

  seminar_page = File.read(
    File.join(temporary_root, "old", "Linux", "Linux服务器管理研讨活动.qmd"),
    encoding: "UTF-8"
  )
  assert(seminar_page.include?("对研讨会有什么意见和建议"), "PageComment data was not migrated")
  assert(seminar_page.include?("是否免费"), "Not all PageComment data was migrated")

  registration_page = File.read(
    File.join(temporary_root, "old", "Linux", "Linux服务器管理研讨活动报名.qmd"),
    encoding: "UTF-8"
  )
  assert(registration_page.include?("czk19790827@gmail.com"), "MailTo content was lost")
  assert(!registration_page.include?("CategoryHomepage"), "MoinMoin category metadata leaked")

  server_page = File.read(
    File.join(temporary_root, "old", "Linux", "Linux服务器管理.qmd"),
    encoding: "UTF-8"
  )
  assert(
    server_page.include?("debian服务器安装.qmd"),
    "Linux server child pages were not migrated"
  )
  assert(
    server_page.include?("ftp_wu-ftpd.qmd"),
    "Nested FTP page was not mapped to a valid output filename"
  )

  mysql_page = File.read(
    File.join(temporary_root, "old", "Linux", "mysql.qmd"),
    encoding: "UTF-8"
  )
  assert(
    mysql_page.include?("源页面不可用"),
    "Unreadable Linux source page is missing its warning"
  )

  ssh_page = File.read(
    File.join(temporary_root, "old", "Linux", "ssh.qmd"),
    encoding: "UTF-8"
  )
  assert(
    ssh_page.include?("number-sections: true"),
    "Linux section numbering pragma was not converted"
  )

  phpbb_page = File.read(
    File.join(temporary_root, "old", "Linux", "phpbb3.qmd"),
    encoding: "UTF-8"
  )
  assert(
    phpbb_page.include?("^[简介：[http://en.wikipedia.org/wiki/Phpbb3]") &&
      phpbb_page.include?("^[apache的安装方法参见[apache](<apache.qmd>)]"),
    "Linked phpBB footnotes were not preserved"
  )

  bind_page = File.read(
    File.join(temporary_root, "old", "Linux", "bind.qmd"),
    encoding: "UTF-8"
  )
  assert(
    bind_page.include?(
      "^[[BIND 9 Administrator Reference Manual]" \
        "(http://www.csd.uwo.ca/staff/magi/doc/bind9/)"
    ),
    "BIND reference footnote was not preserved"
  )

  vi_page = File.read(
    File.join(temporary_root, "old", "Linux", "VI.qmd"),
    encoding: "UTF-8"
  )
  assert(
    vi_page.include?("| :/abc\\\\c | 临时忽略大小写查找字符串abc |"),
    "VI backslash command was not escaped for Markdown tables"
  )
  assert(
    vi_page.include?("| &lt;Tab&gt; | 补全命令 |"),
    "VI literal <Tab> command was lost"
  )

  moinmoin_page = File.read(
    File.join(temporary_root, "old", "Linux", "moinmoin.qmd"),
    encoding: "UTF-8"
  )
  assert(
    moinmoin_page.include?(
      "[MoinMaster:HelpOnInstalling/WikiInstanceCreation]" \
        "(<assets/moinmoin/createinstance.sh>)"
    ),
    "MoinMaster createinstance.sh link was not preserved"
  )
  assert(
    File.exist?(
      File.join(
        temporary_root,
        "old",
        "Linux",
        "assets",
        "moinmoin",
        "createinstance.sh"
      )
    ),
    "MoinMaster createinstance.sh attachment was not copied"
  )

  actual_files.grep(/\.qmd\z/).each do |relative_path|
    page = File.read(File.join(temporary_root, relative_path), encoding: "UTF-8")
    assert(
      !page.include?("#pragma section-numbers"),
      "Section numbering pragma leaked into #{relative_path}"
    )
    assert(
      !page.include?("<<FootNote"),
      "MoinMoin footnote macro leaked into #{relative_path}"
    )
  end
end

puts "Linux migration snapshot replay passed"
