# Pure Nushell Markdown chunker (LangChain-style) with optional byte-based limits.
# - Splits on headings, fenced code blocks, hrules, blank lines, and list starts.
# - Keeps code fences intact.
# - Enforces chunk_size + overlap in *characters* by default, or *bytes* with --bytes.
#
# Usage:
#   open README.md | markdown-chunker --chunk-size 1200 --overlap 200
#   open README.md | markdown-chunker --chunk-size 2048 --overlap 256 --bytes
#   markdown-chunker -t (open README.md | into string) --bytes
#
# Output: list of records { content, meta: { headers, start_line, end_line } }

# ---------- helpers ----------
def byte-len [s: string] -> int {
  # UTF-8 byte length via hex: 2 hex chars per byte
  (($s | into binary | encode hex | str length) / 2)
}

def strlen [s: string, use_bytes: bool] -> int {
  if $use_bytes { byte-len $s } else { $s | str length }
}

def bytes_to_char_index [s: string, target_bytes: int] -> int {
  mut total = 0
  mut idx = 0
  for ch in ($s | split chars) {
    let b = (byte-len $ch)
    if ($total + $b) > $target_bytes { break }
    $total = $total + $b
    $idx = $idx + 1
  }
  $idx
}

def tail_by_len [s: string, n: int, use_bytes: bool] -> string {
  if not $use_bytes {
    let L = ($s | str length)
    let start = (if $n >= $L { 0 } else { $L - $n })
    $s | str substring $start..
  } else {
    let total_b = (byte-len $s)
    let start_b = (if $n >= $total_b { 0 } else { $total_b - $n })
    let start_ci = (bytes_to_char_index $s $start_b)
    $s | str substring $start_ci..
  }
}
def prefix_by_len [s: string, n: int, use_bytes: bool] -> string {
  if not $use_bytes { $s | str substring ..$n }
  else {
    let char_idx = (bytes_to_char_index $s $n)
    $s | str substring ..$char_idx
  }
}

# ---------- main ----------
export def markdown-chunker [
  --chunk-size: int = 1000
  --overlap: int = 200
  --text (-t): string
  --bytes              # if present, measure chunk_size/overlap in bytes
  --ndjson
] {
  let use_bytes = (if $bytes == null { false } else { $bytes })
  let intext = $in
  # read source
  let src = if ($text | is-empty) { $intext | into string } else { $text }
  if ($src | is-empty) { return [] }

  let lines = ($src | split row "\n")

  # detectors
  def is_heading [line: string] { $line =~ '^#{1,6}\s' }
  def is_hrule   [line: string] { $line =~ '^(\*\s*\*\s*\*|-{3,}|_{3,})\s*$' }
  def is_list    [line: string] { $line =~ '^\s*([-*+]\s+|\d+\.\s+)' }
  def is_blank   [line: string] { $line =~ '^\s*$' }
  def is_fence   [line: string] { $line =~ '^\s*(```|~~~)' }

  # state
  mut in_fence = false
  mut buffer = ""
  mut buffer_len = 0               # measured in chars or bytes per --bytes
  mut last_good = 0                # index (same unit as buffer_len)
  mut last_good_line = 0
  mut current_headers = {}
  mut current_start_line = 1
  mut out = []

  # iterate
  for row in ($lines | enumerate) {
    let i = $row.index
    let line = $row.item

    if (is_fence $line) {
      if not $in_fence {
        $in_fence = true
        $last_good = $buffer_len
        $last_good_line = ($i + 1)
      } else {
        $in_fence = false
        # mark a split candidate *after* appending this closing line below
      }
    }

    if (not $in_fence) and (is_heading $line) {
      let level = ($line | str replace -r '^(\#{1,6}).*$' '$1' | str length)
      let text  = ($line | str replace -r '^#{1,6}\s*' '' | str trim)

      # rebuild header path up to `level`
      mut h = {}
      mut k = 1
      while $k < $level {
        let key = $"h($k)"
        if ($current_headers | columns | any {|c| $c == $key}) {
          $h = ($h | insert $key ($current_headers | get $key))
        }
        $k = $k + 1
      }
      $h = ($h | insert $"h($level)" $text)
      $current_headers = $h

      # prefer splitting BEFORE the heading
      $last_good = $buffer_len
      $last_good_line = $i
    }

    if (not $in_fence) and ((is_hrule $line) or (is_blank $line) or (is_list $line)) {
      $last_good = $buffer_len
      $last_good_line = ($i + 1)
    }

    # append line + newline
    let with_nl = ($line + "\n")
    $buffer = ($buffer + $with_nl)
    $buffer_len = ($buffer_len + (strlen $with_nl $use_bytes))

    if (is_fence $line) and (not $in_fence) {
      $last_good = $buffer_len
      $last_good_line = ($i + 1)
    }

    # enforce size
    if $buffer_len >= $chunk_size {
      let split_at = (if $last_good > 0 { $last_good } else { $chunk_size })

      # convert split index to character position if needed
      let char_idx = (if $use_bytes { bytes_to_char_index $buffer $split_at } else { $split_at })

      let chunk = (
        $buffer
        | str substring ..$char_idx
        | str trim -r
      )

      if not ($chunk | is-empty) {
        let end_line = (if $last_good_line > 0 { $last_good_line } else { $i + 1 })
        $out = ($out | append {
          content: $chunk
          meta: { headers: $current_headers start_line: $current_start_line end_line: $end_line }
        })
      }

      # prepare next buffer with overlap
      let overlap_tail = (tail_by_len $chunk $overlap $use_bytes)
      let remainder = ($buffer | str substring $char_idx..)
      $buffer = ($overlap_tail + $remainder)
      $buffer_len = (strlen $buffer $use_bytes)

      $current_start_line = (if $last_good_line > 0 { $last_good_line + 1 } else { $i + 1 })
      $last_good = 0
      $last_good_line = 0
    }
  }

  # flush reminder
  let final_chunk = ($buffer | str trim -r)
  if not ($final_chunk | is-empty) {
    $out = ($out | append {
      content: $final_chunk
      meta: { headers: $current_headers start_line: $current_start_line end_line: ($lines | length) }
    })
  }
  if ($ndjson | default false) {
    # one compact JSON object per line
    $out | each {|r| $r | to json -r } | to text
  } else {
    $out
  }

}