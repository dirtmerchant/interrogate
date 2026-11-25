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
