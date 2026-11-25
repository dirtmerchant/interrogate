# Shared helpers for bin/interrogate and bin/check-citations.
# Sourced, not executed. Bash 3.2 compatible: no associative arrays, no mapfile.

# SHA-256 of a file, hex. shasum ships with macOS; sha256sum with GNU coreutils.
sha256_file() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    echo "no SHA-256 tool found (need shasum or sha256sum)" >&2
    return 1
  fi
}

now_utc() { date -u +%Y-%m-%dT%H:%M:%SZ; }

# jq is the one dependency beyond bash and git. It parses Claude Code's JSON
# output and writes run.json and citations.json with correct escaping.
need_jq() {
  command -v jq >/dev/null 2>&1 && return 0
  echo "$1: jq is required. macOS 15 and later ship /usr/bin/jq; otherwise install it (brew install jq, apt install jq)." >&2
  exit 127
}

# Write stdin to a file atomically: a reader never sees a half-written file.
write_atomic() {
  local dest="$1" tmp
  tmp="$dest.tmp.$$"
  cat > "$tmp" && mv -f "$tmp" "$dest"
}

# Language from a file path, by extension. An awk function, so callers can
# classify thousands of paths in one process. Languages whose imports
# bin/measure extracts are listed in MEASURED_LANGS.
LANG_FOR_AWK='
function lang_for(p,    b, e) {
  b = p; sub(/.*\//, "", b)
  if (b == "Dockerfile" || b ~ /^Dockerfile\./) return "dockerfile"
  if (b == "Makefile" || b == "GNUmakefile") return "make"
  e = b; if (e !~ /\./) return "other"
  sub(/.*\./, "", e); e = tolower(e)
  if (e == "py" || e == "pyi") return "python"
  if (e == "ts" || e == "tsx" || e == "mts" || e == "cts") return "typescript"
  if (e == "js" || e == "jsx" || e == "mjs" || e == "cjs") return "javascript"
  if (e == "go") return "go"
  if (e == "java") return "java"
  if (e == "kt" || e == "kts") return "kotlin"
  if (e == "rb") return "ruby"
  if (e == "cs") return "csharp"
  if (e == "rs") return "rust"
  if (e == "php") return "php"
  if (e == "swift") return "swift"
  if (e == "scala") return "scala"
  if (e == "c" || e == "h") return "c"
  if (e == "cc" || e == "cpp" || e == "cxx" || e == "hpp" || e == "hh") return "cpp"
  if (e == "sh" || e == "bash" || e == "zsh") return "shell"
  if (e == "md" || e == "rst" || e == "txt" || e == "adoc") return "docs"
  if (e == "json" || e == "yaml" || e == "yml" || e == "toml" || e == "ini" || e == "cfg" || e == "xml") return "config"
  return "other"
}'
MEASURED_LANGS="python javascript typescript go java kotlin"
