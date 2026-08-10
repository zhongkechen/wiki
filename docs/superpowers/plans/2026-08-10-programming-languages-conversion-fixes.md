# Programming Languages Conversion Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Correct four reproducible MoinMoin-to-Quarto conversion defects in PR #21 and update the generated migration output.

**Architecture:** Keep all behavior in the existing Ruby migration script. Add narrowly scoped helpers for legacy raw HTML, relative single-bracket links, legacy heading IDs, and section-number pragmas, then lock each behavior into the snapshot replay checker.

**Tech Stack:** Ruby standard library, Quarto, Git

## Global Constraints

- Do not add a Ruby gem or other runtime dependency.
- Do not hand-edit generated migration pages.
- Keep unmatched legacy SGI links unchanged.
- Preserve snapshot-only replay behavior.

---

### Task 1: Add Regression Assertions

**Files:**
- Modify: `tools/check_programming_languages_migration.rb`

**Interfaces:**
- Consumes: generated QMD files produced by the existing migration script.
- Produces: assertions that fail for all four current conversion defects.

- [ ] **Step 1: Add failing raw-HTML assertions**

Read `STL编程指南/deque.qmd` and assert that:

```ruby
assert(!deque_page.match?(/<html\b/i), "Outer legacy HTML wrapper leaked")
assert(
  deque_page.include?('href="Random Access Container.html"'),
  "Legacy SGI page links were not rewritten"
)
assert(
  !deque_page.match?(/src\s*=\s*"(?:\/images\/common\/sgilogo_small\.gif|containers\.gif|type\.gif)"/i),
  "Unavailable legacy images were retained"
)
```

- [ ] **Step 2: Add failing PIL link assertions**

Read `PythonImageLibrary中文手册.qmd` and assert:

```ruby
assert(
  pil_page.include?("[getbands](<image.htm#image-getbands-method>)"),
  "Relative MoinMoin file link was not converted"
)
assert(
  pil_page.include?("#### open {#image-open-function}"),
  "Legacy PIL fragment ID was not preserved"
)
```

- [ ] **Step 3: Add failing section-number assertions**

Read `C++编程基础.qmd` and assert:

```ruby
assert(!cpp_basics.include?("#pragma section-numbers"), "Moin pragma leaked")
assert(
  cpp_basics.include?("number-sections: true"),
  "Moin section numbering was not mapped to Quarto"
)
```

- [ ] **Step 4: Run the checker and verify RED**

Run:

```bash
ruby tools/check_programming_languages_migration.rb
```

Expected: FAIL first on the outer legacy HTML assertion.

### Task 2: Implement Conversion Fixes

**Files:**
- Modify: `tools/migrate_moin_programming_languages.rb`

**Interfaces:**
- Consumes: existing source snapshot records and raw MoinMoin content.
- Produces: deterministic QMD output with corrected links, anchors, HTML, and front matter.

- [ ] **Step 1: Define scoped legacy mappings**

Add constants for:

```ruby
LEGACY_HTML_PAGE_LINKS = {
  "Vector.html" => "STL编程指南/vector",
  "List.html" => "STL编程指南/list",
  "Slist.html" => "STL编程指南/slist",
  "Deque.html" => "STL编程指南/deque",
  "ForwardContainer.html" => "STL编程指南/Forward Container",
  "RandomAccessContainer.html" => "STL编程指南/Random Access Container",
  "FrontInsertionSequence.html" => "STL编程指南/Front Insertion Sequence",
  "BackInsertionSequence.html" => "STL编程指南/Back Insertion Sequence",
  "ReversibleContainer.html" => "STL编程指南/Reversible Container"
}.freeze
```

Also add the three unavailable image targets and the PIL heading ID map.

- [ ] **Step 2: Normalize legacy HTML**

Add `normalize_legacy_html(body, owner:, context:)` that:

1. strips outer `html`, `head`, and `body` tags case-insensitively;
2. removes image tags for the unavailable decorative sources, including an
   enclosing empty anchor;
3. rewrites mapped `href` values to the generated relative `.html` target;
4. leaves anchors, external URLs, and unmatched legacy URLs unchanged.

Pass `owner` and `context` into `convert_blocks` so HTML normalization can use
the existing page path logic.

- [ ] **Step 3: Convert relative single-bracket file links**

Before the current scheme-based single-bracket conversion, add a conversion
for targets containing a file extension:

```ruby
[image.htm#image-getbands-method getbands]
```

must become:

```markdown
[getbands](<image.htm#image-getbands-method>)
```

The matcher must not consume `[[...]]`, numeric references, or array syntax.

- [ ] **Step 4: Preserve the PIL fragment ID**

When rendering headings, append `{#image-open-function}` to the `open` heading
only for `PythonImageLibrary中文手册`.

- [ ] **Step 5: Map section-number pragmas**

Add a predicate for `#pragma section-numbers N`, remove matching directive
lines during body conversion, and extend `qmd_front_matter` with a
`number_sections:` keyword that emits:

```yaml
number-sections: true
```

Pass the predicate result when generating each page.

- [ ] **Step 6: Run the checker and verify GREEN**

Run:

```bash
ruby tools/check_programming_languages_migration.rb
```

Expected: `Programming languages migration snapshot replay passed`.

### Task 3: Regenerate and Audit Output

**Files:**
- Modify: generated files under `old/程序设计语言/`
- Modify if regenerated: `tools/data/moin_programming_languages_sources.json`

**Interfaces:**
- Consumes: the corrected migration script and source data.
- Produces: committed migration output matching snapshot replay.

- [ ] **Step 1: Regenerate migration output**

Run:

```bash
ruby tools/migrate_moin_programming_languages.rb
```

Expected:

```text
Converted 147 pages
Copied 36 attachments
```

- [ ] **Step 2: Re-run snapshot replay**

Run:

```bash
ruby tools/check_programming_languages_migration.rb
```

Expected: PASS.

- [ ] **Step 3: Audit corrected output**

Verify:

```bash
rg -n 'RandomAccessContainer\.html|FrontInsertionSequence\.html|BackInsertionSequence\.html|ForwardContainer\.html|ReversibleContainer\.html|Vector\.html|List\.html|Slist\.html|Deque\.html' old/程序设计语言/STL编程指南/{Container,deque}.qmd
```

Expected: no matches.

Verify:

```bash
rg -n '^\#pragma section-numbers|\[(image|formats|decoder|imagechops)\.htm' old/程序设计语言 -g '*.qmd'
```

Expected: no matches.

### Task 4: Full Verification and PR Update

**Files:**
- Verify all changed files.

**Interfaces:**
- Consumes: regenerated migration output.
- Produces: a tested commit pushed to `codex/migrate-programming-languages`.

- [ ] **Step 1: Check whitespace and diff**

Run:

```bash
git diff --check
git status --short
```

Expected: no whitespace errors; only intended files changed.

- [ ] **Step 2: Render the complete Quarto project**

Run:

```bash
env HOME=/home/czk/.codex-tmp/quarto-home XDG_CACHE_HOME=/home/czk/.codex-tmp/quarto-cache quarto render
```

Expected: exit code 0.

- [ ] **Step 3: Commit the fixes**

Run:

```bash
git add tools/migrate_moin_programming_languages.rb \
  tools/check_programming_languages_migration.rb \
  old/程序设计语言.qmd old/程序设计语言
git commit -m "Fix programming language migration conversion errors"
```

- [ ] **Step 4: Push the PR branch**

Run:

```bash
git push origin codex/migrate-programming-languages
```

- [ ] **Step 5: Confirm PR head and checks**

Run:

```bash
gh pr view 21 --json url,headRefName,commits
gh pr checks 21
```

Expected: PR #21 points to the pushed commit; checks are running or passing.
