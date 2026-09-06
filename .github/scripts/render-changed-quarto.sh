#!/usr/bin/env bash

set -euo pipefail

base_sha="${BASE_SHA:-}"
head_sha="${HEAD_SHA:-}"
event_name="${GITHUB_EVENT_NAME:-}"
cache_matched_key="${SITE_CACHE_MATCHED_KEY:-}"

declare -a changed_files=()
declare -a diff_commits=()
declare -a removed_or_renamed_files=()
declare -a render_files=()
declare -A render_file_seen=()

set_rendered_output() {
  if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    printf 'rendered=%s\n' "$1" >> "$GITHUB_OUTPUT"
  fi
}

render_all() {
  local reason="$1"

  echo "Running a full render: ${reason}"
  quarto render
  set_rendered_output true
  exit 0
}

add_render_file() {
  local file="$1"

  if [[ ! -f "$file" || -n "${render_file_seen[$file]+present}" ]]; then
    return
  fi

  render_file_seen["$file"]=1
  render_files+=("$file")
}

is_site_input() {
  local file="$1"

  case "$file" in
    _quarto.yml | CNAME | LICENSE.md | index.md | *.qmd | health/* | old/* | wiki/*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

if [[ "$event_name" == "workflow_dispatch" ]]; then
  render_all "manual workflow dispatch"
fi

if [[ "$event_name" != "pull_request" && -z "$cache_matched_key" ]]; then
  render_all "no previous rendered-site cache is available"
fi

if [[ -z "$base_sha" || "$base_sha" =~ ^0+$ ]]; then
  render_all "the base commit is unavailable"
fi

if ! git cat-file -e "${base_sha}^{commit}" 2>/dev/null ||
  ! git cat-file -e "${head_sha}^{commit}" 2>/dev/null; then
  render_all "the commits required for the incremental diff are unavailable"
fi

if [[ "$event_name" == "pull_request" ]]; then
  diff_commits=("${base_sha}...${head_sha}")
else
  diff_commits=("$base_sha" "$head_sha")
fi

mapfile -d '' -t changed_files < <(
  git diff --name-only --diff-filter=ACMRT -z "${diff_commits[@]}" --
)
mapfile -d '' -t removed_or_renamed_files < <(
  git diff --name-only --diff-filter=DR -z "${diff_commits[@]}" --
)

for file in "${removed_or_renamed_files[@]}"; do
  if is_site_input "$file"; then
    render_all "a site input was deleted or renamed: ${file}"
  fi
done

for file in "${changed_files[@]}"; do
  case "$file" in
    _quarto.yml | CNAME)
      render_all "a global site input changed: ${file}"
      ;;
    *.qmd | LICENSE.md | index.md | wiki/*.md)
      add_render_file "$file"
      if [[ "$file" == health/posts/* ]]; then
        add_render_file "health/index.qmd"
      fi
      ;;
    health/* | old/* | wiki/*)
      render_all "a non-document site resource changed: ${file}"
      ;;
  esac
done

if ((${#render_files[@]} == 0)); then
  echo "No rendered document changed."
  set_rendered_output false
  exit 0
fi

for file in "${render_files[@]}"; do
  echo "Rendering changed document: ${file}"
  quarto render "$file" --no-clean
done

set_rendered_output true
