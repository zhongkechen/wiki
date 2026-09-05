# Wiki 项目工作指南

## 项目用途

本仓库使用 Quarto 生成个人 Wiki 静态网站，并通过 GitHub Pages 发布。

主要目录和文件：

- `index.md`：网站首页和各专题入口。
- `wiki/`：当前维护的普通 Wiki 页面。
- `<专题>/index.qmd`：专题或博客首页，例如 `health/index.qmd`。
- `<专题>/posts/`：专题文章目录。
- `old/`：旧版 Wiki 迁移内容，默认只做必要修正。
- `_quarto.yml`：站点配置和显式渲染清单。
- `.github/workflows/pages.yml`：Quarto 构建及 GitHub Pages 发布流程。
- `_site/`、`.quarto/`：本地生成目录，不提交。

## 核心原则

1. 只修改完成当前任务所需的文件，不顺手整理无关内容。
2. 工作区中的已有改动属于用户，不得暂存、还原、覆盖或擅自合并。
3. 工作区不干净时，优先从最新 `origin/master` 创建独立 worktree，避免混入用户改动；临时 worktree 必须放在 `$TMPDIR`，禁止使用 `/tmp`。
4. 不直接提交或推送到 `master`。所有更新必须通过独立分支和 Pull Request。
5. 分支名应简洁描述任务，不得添加 `codex/` 前缀。
6. PR 检查通过后，除非用户明确要求，否则不要代替用户合并 PR。
7. 用户要求“发布”时，合并后还要确认 GitHub Pages 的构建和部署成功，不能只以 PR 合并为完成。

## 开始任务

开始修改前：

1. 检查当前分支和工作区：

   ```bash
   git status --short --branch
   ```

2. 获取最新远程状态：

   ```bash
   git fetch origin --prune
   ```

3. 工作区干净时，从最新 `master` 建立任务分支：

   ```bash
   git switch master
   git pull --ff-only origin master
   git switch -c <任务分支名>
   ```

4. 工作区存在用户改动时，不得 stash 或还原；从 `origin/master` 建立独立 worktree：

   ```bash
   task_root="$(mktemp -d "$TMPDIR/wiki-worktree.XXXXXX")"
   git worktree add "$task_root/worktree" -b <任务分支名> origin/master
   ```

## 内容组织

### 普通 Wiki 页面

- 当前维护页面放入 `wiki/`。
- 新页面需要加入 `_quarto.yml` 的 `project.render`。
- 需要从首页进入的新一级主题，应同时在 `index.md` 添加入口。

### 专题博客

- 专题首页使用 `<专题>/index.qmd`。
- 文章使用 `<专题>/posts/<slug>/index.qmd`。
- 专题首页使用 Quarto `listing` 自动生成文章列表；需要订阅时启用 `feed: true`。
- 新专题及文章路径必须加入 `_quarto.yml` 的渲染清单。

### 外部内容归档

- 从小红书项目同步的文章属于原文存档，不得在 Wiki 中单独改写、事实校订或删减。
- 小红书原文在共享工作区可用时，以 `../obsidian-notes/projects/rednote/` 下对应文章为正文来源。
- 需要修改归档文章时，必须在小红书项目和 Wiki 项目中同步修改，保持两边正文一致。
- 用户要求纯文字归档时，不得在 Wiki 文章中加入原图或图片引用。
- 小红书、中文视频和英文原片等来源链接可以按用户要求追加到文章末尾，但不得借此改动原文正文。

## Markdown 与 Quarto 约定

- 页面使用 Markdown 或 Quarto Markdown，结构化页面应包含 YAML frontmatter。
- 日期使用 `YYYY-MM-DD`。
- 标题层级不得跳级；一个页面只保留一个由 frontmatter 或正文提供的主标题。
- 新增专题文章时，使用有意义、稳定的英文 slug。
- 不提交 `_site/`、`.quarto/`、日志、缓存或其他构建产物。
- 不把敏感信息、访问令牌或带临时认证参数的链接写入页面。

## 验证

提交前至少执行：

```bash
git diff --check
git status --short
```

按改动类型补充检查：

- YAML/frontmatter：确认语法可解析。
- 原文归档：将正文与来源文件逐段或逐字比较。
- 纯文字文章：确认目标目录中没有 `![...]`、`<img>` 或 `image:` 引用。
- 页面解析：可使用 Quarto 自带 Pandoc 验证 Markdown。
- 站点构建：

  ```bash
  quarto render
  ```

如果 Quarto 默认缓存目录不可写，使用：

```bash
XDG_CACHE_HOME="$TMPDIR/quarto-cache" quarto render
```

本仓库历史页面较多，全站构建可能需要数分钟。PR 中的 `Build and deploy Quarto site` 检查是最终构建依据；检查失败时，应查看日志并在同一分支修复。

## 提交与 Pull Request

1. 只暂存本次任务的文件。
2. 提交信息使用简洁中文，说明改动目的。
3. 将当前任务分支推送到同名远程分支：

   ```bash
   git push -u origin <任务分支名>
   ```

4. 使用 GitHub CLI 创建 PR，目标分支固定为 `master`：

   ```bash
   gh pr create --base master --head <任务分支名>
   ```

5. PR 描述至少包含：

   - 修改内容。
   - 关键约束，例如“正文与来源保持一致”“不包含图片”。
   - 已执行的验证。
   - 未完成或只能由 CI 验证的事项。

6. 监控 PR 检查：

   ```bash
   gh pr checks <PR编号>
   ```

7. 未经用户明确要求，不执行 `gh pr merge`。
8. PR 合并后，如任务包含发布，继续确认 `master` 上的 Pages 工作流完成且部署成功。

## 完成前检查

- 变更来自最新 `origin/master`。
- 工作区中用户已有改动未被修改或带入提交。
- 新页面已进入 `_quarto.yml` 渲染清单。
- 首页或专题入口已按需要更新。
- 归档正文与来源保持一致。
- 用户要求无图时，文章确实不包含图片。
- 提交只包含当前任务文件。
- 分支已推送，PR 已创建，检查状态已报告。
