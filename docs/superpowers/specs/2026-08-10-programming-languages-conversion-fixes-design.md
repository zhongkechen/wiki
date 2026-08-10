# Programming Languages Conversion Fixes

## Goal

Fix the conversion defects identified in PR #21 without adding runtime
dependencies or hand-editing generated pages.

## Scope

The migration must:

- rewrite legacy raw-HTML links that correspond to migrated STL pages;
- remove unavailable decorative images and outer HTML document wrappers from
  imported SGI pages;
- map the seven PIL handbook links to stable fragments in the merged page;
- preserve stable fragments for all linked PIL headings;
- remove `#pragma section-numbers 2` from rendered content and enable Quarto
  section numbering for the affected pages;
- render trusted `#!raw` blocks as raw markup instead of code and upgrade the
  known Google Docs iframe to HTTPS;
- protect C++ `operator[]` signatures from Markdown link parsing;
- convert MoinMoin emphasis one line at a time, normalizing delimiter
  whitespace and repairing the one malformed source marker.

Links to SGI pages that were not migrated are outside this fix. They remain
unchanged rather than being redirected to an unverified external archive.

## Design

Keep the migration self-contained in
`tools/migrate_moin_programming_languages.rb`.

For raw HTML, use a constrained legacy-HTML normalization pass. The input is
known migration data rather than arbitrary web content, and the repository has
no tolerant HTML parser dependency. The pass will strip outer document tags,
remove the three unavailable decorative images, and rewrite a fixed set of SGI
filenames to the corresponding generated `.html` paths.

Extend the existing single-bracket link conversion only for targets that look
like relative files with extensions. Map the known PIL targets to stable
same-page fragments and leave unmatched relative targets as relative links.
This avoids interpreting array notation and numeric references as links.

Use a page-specific legacy heading ID map, including occurrence-aware IDs for
the repeated PIL `offset` heading. Detect MoinMoin's section-number pragma
before body conversion, remove it from the body, and add
`number-sections: true` to that page's YAML.

Treat `#!raw` as trusted raw markup, matching the existing `#!html` behavior,
and upgrade the known Google Docs iframe so an HTTPS site does not block it as
mixed content. Replace `operator[]` only when it begins a function-call
signature, after code blocks have been tokenized, using HTML entities for the
brackets. Convert bold and italic markers independently on each source line so
malformed markup cannot consume later paragraphs.

## Verification

Add regression assertions to
`tools/check_programming_languages_migration.rb` before changing the converter.
The assertions must fail against the current implementation and cover every
defect above.

After implementation:

1. replay the snapshot migration;
2. confirm generated local Markdown and raw-HTML references are valid for the
   migrated targets;
3. run `git diff --check`;
4. render the full Quarto project;
5. commit and push the PR branch.
