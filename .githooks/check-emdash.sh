#!/usr/bin/env bash
# ==============================================================================
# Script: check-emdash.sh
# Purpose: Scan files/commits for literal em dashes (Unicode U+2014)
# Behavior: Emits a structured diagnostic mandate to stdout/stderr and exits with 1.
# Target: LLM Agentic Coding Agents & Developers
# ==============================================================================

set -euo pipefail

# Define em dash using UTF-8 byte sequence to avoid literal em dash in source
TARGET_CHAR=$'\xe2\x80\x94'
UNICODE_HEX="U+2014"

MODE="staged" # Options: staged, all, commit-msg, range, files
COMMIT_MSG_FILE=""
COMMIT_RANGE=""
EXPLICIT_FILES=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all)
      MODE="all"
      shift
      ;;
    --staged)
      MODE="staged"
      shift
      ;;
    --range)
      MODE="range"
      COMMIT_RANGE="$2"
      shift 2
      ;;
    --commit-msg)
      MODE="commit-msg"
      COMMIT_MSG_FILE="$2"
      shift 2
      ;;
    --files)
      MODE="files"
      shift
      while [[ $# -gt 0 && "$1" != --* ]]; do
        EXPLICIT_FILES+=("$1")
        shift
      done
      ;;
    *)
      shift
      ;;
  esac
done

VIOLATIONS_FOUND=0
VIOLATION_COUNT=0

REPORT_FILE=$(mktemp 2>/dev/null || mktemp -t 'emdash_report')
trap 'rm -f "$REPORT_FILE"' EXIT

is_binary() {
  local file="$1"
  if [ ! -f "$file" ]; then
    return 0
  fi
  # Fast check: git check-attr
  if git check-attr -z diff "$file" 2>/dev/null | grep -q "diff: unset"; then
    return 0
  fi
  # Check file extension for common binary files
  case "$file" in
    *.exe|*.dll|*.bin|*.pdf|*.png|*.jpg|*.jpeg|*.gif|*.ico|*.zip|*.tar|*.gz|*.7z|*.woff|*.woff2|*.ttf|*.eot)
      return 0
      ;;
  esac
  # Fallback to grep binary check
  if LC_ALL=C grep -qI '.' "$file" 2>/dev/null; then
    return 1 # text file
  else
    return 0 # binary file
  fi
}

get_file_category() {
  local file="$1"
  case "$file" in
    *.ps1|*.psm1|*.psd1|*.py|*.js|*.jsx|*.ts|*.tsx|*.sh|*.bash|*.cs|*.go|*.rs|*.c|*.cpp|*.h|*.java|*.json|*.yaml|*.yml|*.toml|*.xml)
      echo "CODE_OR_SCRIPT"
      ;;
    *.md|*.markdown|*.txt|*.rst|*.adoc|*.html|*.htm|*.tex)
      echo "DOCUMENTATION"
      ;;
    *)
      if [[ "$file" == *"COMMIT_EDITMSG"* ]] || [[ "$file" == *"commit-msg"* ]]; then
        echo "COMMIT_MESSAGE"
      else
        echo "OTHER_TEXT"
      fi
      ;;
  esac
}

check_file() {
  local file="$1"
  if [ ! -f "$file" ]; then
    return
  fi
  if is_binary "$file"; then
    return
  fi
  # Skip third-party vendor/installed directories (e.g. BMAD framework files)
  case "$file" in
    _bmad/*|.claude/skills/bmad-*)
      return
      ;;
  esac

  local category
  category=$(get_file_category "$file")

  local line_num=0
  while IFS= read -r line || [ -n "$line" ]; do
    line_num=$((line_num + 1))
    if [[ "$line" == *"$TARGET_CHAR"* ]]; then
      VIOLATIONS_FOUND=1
      VIOLATION_COUNT=$((VIOLATION_COUNT + 1))

      local prefix="${line%%${TARGET_CHAR}*}"
      local col_num=$((${#prefix} + 1))

      echo "  • [FILE] $file" >> "$REPORT_FILE"
      echo "    [TYPE] Category: $category | Line $line_num, Column $col_num" >> "$REPORT_FILE"
      echo "    [CODE] $line" >> "$REPORT_FILE"

      # Build visual pointer indicator
      local pointer_pad=""
      if [ "$col_num" -gt 1 ]; then
        pointer_pad=$(printf '%*s' "$((col_num - 1))" '')
      fi
      echo "    [SPOT] ${pointer_pad}^^^ [FORBIDDEN CHARACTER: EM DASH (${UNICODE_HEX})]" >> "$REPORT_FILE"
      echo "" >> "$REPORT_FILE"
    fi
  done < "$file"
}

# Collect target files
if [ "$MODE" = "commit-msg" ]; then
  if [ -n "$COMMIT_MSG_FILE" ] && [ -f "$COMMIT_MSG_FILE" ]; then
    check_file "$COMMIT_MSG_FILE"
  fi
elif [ "$MODE" = "files" ]; then
  for file in "${EXPLICIT_FILES[@]}"; do
    check_file "$file"
  done
elif [ "$MODE" = "range" ]; then
  _files_tmp=$(mktemp)
  git diff --name-only --diff-filter=ACM "$COMMIT_RANGE" 2>/dev/null > "$_files_tmp"
  while IFS= read -r file; do
    if [ -n "$file" ] && [ -f "$file" ]; then
      check_file "$file"
    fi
  done < "$_files_tmp"
  rm -f "$_files_tmp"
elif [ "$MODE" = "all" ]; then
  _files_tmp=$(mktemp)
  (git ls-files 2>/dev/null || find . -type f -not -path '*/.*/*') > "$_files_tmp"
  while IFS= read -r file; do
    check_file "$file"
  done < "$_files_tmp"
  rm -f "$_files_tmp"
else
  # Inspect staged files (added, copied, modified)
  _files_tmp=$(mktemp)
  git diff --cached --name-only --diff-filter=ACM 2>/dev/null > "$_files_tmp"
  while IFS= read -r file; do
    if [ -n "$file" ] && [ -f "$file" ]; then
      check_file "$file"
    fi
  done < "$_files_tmp"
  rm -f "$_files_tmp"
fi

# If violations exist, output complete diagnostic mandate and halt git operation
if [ "$VIOLATIONS_FOUND" -ne 0 ]; then
  cat << 'EOF' >&2

================================================================================
 🛑 [GIT HOOK BLOCKED] EM DASH POLICY VIOLATION DETECTED
================================================================================

The git operation was REJECTED because the prohibited literal em dash character
(Unicode U+2014 / UTF-8 0xE2 0x80 0x94) was found in your changes.

--- OFFENDING LOCATIONS --------------------------------------------------------
EOF
  cat "$REPORT_FILE" >&2
  cat << 'EOF' >&2
--------------------------------------------------------------------------------

================================================================================
 📋 MANDATE FOR AI CODING AGENT / LLM (MANDATORY INSTRUCTIONS)
================================================================================
1. ZERO-TOLERANCE POLICY: Literal em dashes (Unicode U+2014) are strictly prohibited
   in this repository across all scripts, code, documentation, comments, and messages.
2. DO NOT BYPASS: Do not use '--no-verify' or force flags to circumvent this check.
3. CONTEXT-AWARE REPAIR: You must rewrite the offending content according to its file
   category and semantic purpose:

💡 RESOLUTION PROTOCOL BY CONTEXT:

  [A] SCRIPT & CODE FILES (.ps1, .py, .js, .ts, .sh, .cs, .json, etc.):
      • CLI Flags / Operators: If an em dash was inserted for a flag or operator,
        replace with standard ASCII hyphen '-' or '--'.
      • String Literals / UI text: Replace with ' - ' or ':' or rewrite the text.
      • Char Matching / Regex: If testing for U+2014, use escape sequences
        (e.g., '\u2014' or [char]0x2014) rather than a raw literal character.
      • Code Comments: Rephrase comments using standard ASCII punctuation ('--', '-', ':').

  [B] DOCUMENTATION & PROSE (.md, .txt, .rst, docs, README):
      • Spaced Hyphen / Double Hyphen: Replace em dash with ' - ' or '--'.
      • Colon / Semicolon: Use ':' for explanations/definitions or ';' between clauses.
      • Parentheses: Wrap parenthetical remarks in '( ... )'.
      • Sentence Splitting: Split the run-on sentence into two distinct sentences.

  [C] COMMIT MESSAGES:
      • Replace em dash with ' - ' or ':' or rephrase the commit summary.

🚀 REQUIRED AGENT ACTION SEQUENCE:
   Step 1: Inspect each file and line number listed in the report above.
   Step 2: Edit the lines to eliminate the em dash using the proper Context Resolution Rule.
   Step 3: Stage the corrected files: git add <files>
   Step 4: Retry your git commit / git push command.
================================================================================

EOF
  exit 1
fi

exit 0
