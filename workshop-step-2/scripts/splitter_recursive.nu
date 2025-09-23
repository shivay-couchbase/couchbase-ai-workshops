# recursive-chunker.nu
#
# Pure Nushell port of LangChainJS's RecursiveCharacterTextSplitter with language presets.
# - Recursive, priority separators (default ["\n\n", "\n", " ", ""])
# - chunk_size + chunk_overlap
# - --keep-separator attaches separators to the left piece
# - --bytes measures budgets in BYTES (portable via hex), never breaks Unicode
# - --ndjson outputs one compact JSON object per line
# - get-separators-for-language + recursive-chunker-from-language convenience
#
# Usage:
#   open README.md | recursive-chunker --chunk-size 1000 --overlap 200
#   open file.py   | recursive-chunker-from-language --language python --chunk-size 1200 --overlap 200
#   open index.ts  | recursive-chunker-from-language --language ts --bytes --chunk-size 4096 --overlap 256 --ndjson
#   recursive-chunker -t "# Title\n\nPara one.\n\nPara two." --chunk-size 12 --overlap 3

# ---------- length helpers (portable byte counting) ----------
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

def prefix_by_len [s: string, n: int, use_bytes: bool] -> record<char_idx: int, text: string> {
  if not $use_bytes {
    let ci = (if $n < 0 { 0 } else { $n })
    { char_idx: $ci, text: ($s | str substring ..$ci) }
  } else {
    let ci0 = (bytes_to_char_index $s (if $n < 0 { 0 } else { $n }))
    let ci = (if $ci0 == 0 and ($s | str length) > 0 { 1 } else { $ci0 })
    { char_idx: $ci, text: ($s | str substring ..$ci) }
  }
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

# ---------- splitting primitives ----------
def split_once [text: string, sep: string, keep_separator: bool] -> record<had_sep: bool, parts: list<string>> {
  if $sep == "" {
    let parts = ($text | split chars)
    { had_sep: (($parts | length) > 1), parts: $parts }
  } else {
    let raw = ($text | split row $sep)
    if not $keep_separator {
      { had_sep: (($raw | length) > 1), parts: $raw }
    } else {
      # attach sep to the left piece (except the last)
      let n = ($raw | length)
      let parts = ($raw | enumerate | each {|it|
        if $it.index < ($n - 1) { $it.item + $sep } else { $it.item }
      })
      { had_sep: ($n > 1), parts: $parts }
    }
  }
}

def hard_split [s: string, limit: int, use_bytes: bool] -> list<string> {
  mut out = []
  mut rest = $s
  while ($rest | str length) > 0 {
    let p = (prefix_by_len $rest $limit $use_bytes)
    let piece = $p.text
    let cut = $p.char_idx
    if ($piece | is-empty) {
      # guard to avoid infinite loop under tiny budgets
      let first_char = ($rest | str substring ..1)
      $out = ($out | append $first_char)
      $rest = ($rest | str substring 1..)
    } else {
      $out = ($out | append $piece)
      $rest = ($rest | str substring $cut..)
    }
  }
  $out
}

# Recursively split a string using prioritized separators
def split_recurse [
  text: string,
  separators: list<string>,
  depth: int,
  chunk_size: int,
  use_bytes: bool,
  keep_separator: bool
] -> list<string> {
  if $depth >= ($separators | length) {
    if (strlen $text $use_bytes) <= $chunk_size { return [ $text ] } else { return (hard_split $text $chunk_size $use_bytes) }
  }

  let sep = ($separators | get $depth)
  let s1 = (split_once $text $sep $keep_separator)

  if not $s1.had_sep {
    if ($depth + 1) < ($separators | length) {
      return (split_recurse $text $separators ($depth + 1) $chunk_size $use_bytes $keep_separator)
    } else {
      if (strlen $text $use_bytes) <= $chunk_size { return [ $text ] } else { return (hard_split $text $chunk_size $use_bytes) }
    }
  }

  mut out = []
  for p in $s1.parts {
    if (strlen $p $use_bytes) <= $chunk_size {
      $out = ($out | append $p)
    } else {
      let deeper = (split_recurse $p $separators ($depth + 1) $chunk_size $use_bytes $keep_separator)
      $out = ($out | append $deeper)
    }
  }
  $out
}

# Merge pre-splits into chunks with size+overlap
def merge_chunks [
  pieces: list<string>,
  chunk_size: int,
  overlap: int,
  use_bytes: bool,
  keep_separator: bool,
  chosen_sep: string
] -> list<string> {
  mut current = ""
  mut clen = 0
  mut out = []

  for p in $pieces {
    if ($p | is-empty) { continue }

    let addition = (if ($keep_separator or ($chosen_sep == "") or ($current | is-empty)) { $p } else { $chosen_sep + $p })
    let add_len = (strlen $addition $use_bytes)

    if ($clen + $add_len) > $chunk_size {
      if not ($current | is-empty) {
        $out = ($out | append ($current | str trim -r))
        let tail = (tail_by_len $current $overlap $use_bytes)
        $current = $tail
        $clen = (strlen $current $use_bytes)
      }

      if $add_len > $chunk_size {
        let cuts = (hard_split $addition $chunk_size $use_bytes)
        for $it in ($cuts | enumerate) {
          if $it.index == 0 {
            $current = $it.item
            $clen = (strlen $current $use_bytes)
          } else {
            $out = ($out | append ($current | str trim -r))
            let tail = (tail_by_len $current $overlap $use_bytes)
            $current = ($tail + $it.item)
            $clen = (strlen $current $use_bytes)
          }
        }
      } else {
        $current = ($current + $addition)
        $clen = (strlen $current $use_bytes)
      }
    } else {
      $current = ($current + $addition)
      $clen = (strlen $current $use_bytes)
    }
  }

  if not ($current | is-empty) {
    $out = ($out | append ($current | str trim -r))
  }

  $out
}

# ---------- language presets ----------
def normalize-language [lang: string] -> string {
  let l = (($lang | default "" | str downcase | str trim))
  match $l {
  "md" | "markdown" | "mdx" => "markdown",
  "tex" | "latex" => "latex",
  "html" | "htm" | "xhtml" | "xml" => "html",
  "py" | "python" => "python",
  "js" | "javascript" => "javascript",
  "ts" | "typescript" => "typescript",
  "sol" | "solidity" => "solidity",
  "java" => "java",
  "cs" | "csharp" | "c#" => "csharp",
  "c++" | "cpp" | "hpp" | "cc" | "cxx" => "cpp",
  "c" => "c",
  "go" | "golang" => "go",
  "rs" | "rust" => "rust",
  "kt" | "kotlin" => "kotlin",
  "swift" => "swift",
  "rb" | "ruby" => "ruby",
  "php" => "php",
  "sql" => "sql",
  "sh" | "bash" | "zsh" | "shell" => "shell",
  "nu" | "nushell" => "nushell",
  _ => "plain"
}
}

# Returns a prioritized list of separators for a language.
# NOTE: This is heuristic and intentionally simple (string separators only).
export def get-separators-for-language [language: string] -> list<string> {
  let L = (normalize-language $language)

  match $L {
    "markdown" => [ "\n# " "\n## " "\n### " "\n#### " "\n##### " "\n###### " "\n```" "\n\n" "\n" " " "" ],
    "latex" => [ "\n\\chapter{" "\n\\section{" "\n\\subsection{" "\n\\begin{" "\n\\end{" "\n\n" "\n" " " "" ],
    "html" => [ "\n</section>" "\n</div>" "\n</p>" "\n</li>" "\n</ul>" "\n</ol>" "\n</table>" "\n</tr>" "\n</td>" "\n</" "\n<" "\n\n" "\n" " " "" ],
    "python" => [ "\nclass " "\ndef " "\nasync def " "\nif " "\nfor " "\nwhile " "\ntry:" "\nwith " "\n\n" "\n" " " "" ],
    "javascript" => [ "\nclass " "\nfunction " "\nexport " "\nimport " "\nconst " "\nlet " "\n=>" "\n\n" "\n" " " "" ],
    "typescript" => [ "\nclass " "\nfunction " "\nexport " "\nimport " "\ninterface " "\ntype " "\nconst " "\nlet " "\n=>" "\n\n" "\n" " " "" ],
    "java" => [ "\nclass " "\ninterface " "\nenum " "\npublic " "\nprivate " "\nprotected " "\nstatic " "\nvoid " "\n\n" "\n" " " "" ],
    "csharp" => [ "\nnamespace " "\nclass " "\nstruct " "\ninterface " "\npublic " "\nprivate " "\nprotected " "\nstatic " "\nvoid " "\n\n" "\n" " " "" ],
    "cpp" => [ "\nclass " "\nstruct " "\nnamespace " "\ntemplate<" "\nvoid " "\nint " "\nreturn " "\n\n" "\n" " " "" ],
    "c" => [ "\nvoid " "\nint " "\nchar " "\nfloat " "\ndouble " "\nstruct " "\nreturn " "\n\n" "\n" " " "" ],
    "go" => [ "\npackage " "\nimport " "\nfunc " "\ntype " "\nconst " "\nvar " "\nreturn " "\n\n" "\n" " " "" ],
    "rust" => [ "\nmod " "\nuse " "\nimpl " "\nfn " "\nstruct " "\nenum " "\ntrait " "\nlet " "\nreturn " "\n\n" "\n" " " "" ],
    "kotlin" => [ "\nclass " "\nobject " "\ninterface " "\nfun " "\nval " "\nvar " "\ncompanion object" "\n\n" "\n" " " "" ],
    "swift" => [ "\nclass " "\nstruct " "\nenum " "\nprotocol " "\nfunc " "\nextension " "\nlet " "\nvar " "\n\n" "\n" " " "" ],
    "ruby" => [ "\nclass " "\nmodule " "\ndef " "\nend" "\n\n" "\n" " " "" ],
    "php" => [ "<?php" "?>" "\nclass " "\nfunction " "\nif (" "\nforeach" "\n\n" "\n" " " "" ],
    "sql" => [ "\nSELECT " "\nFROM " "\nWHERE " "\nINSERT " "\nUPDATE " "\nDELETE " "\nCREATE " "\nALTER " "\n\n" "\n" " " "" ],
    "solidity" => [ "\ncontract " "\ninterface " "\nlibrary " "\nfunction " "\nmodifier " "\nevent " "\nstruct " "\n\n" "\n" " " "" ],
    "shell" => [ "\nfunction " "\n#" "\n\n" "\n" " " "" ],
    "nushell" => ["\nmatch " "\nwhile " "\nfor " "\nif " "\ndef " "\nexport " "\n#" "\n\n" "\n" " " "" ],
    _ => [ "\n\n" "\n" " " "" ] # plain text fallback
}
}



# ---------- core executor to avoid arg-spreading ----------
def run-chunker [
  src: string,
  seps: list<string>,
  chunk_size: int,
  overlap: int,
  keep_sep: bool,
  use_bytes: bool,
  ndjson: bool
] {
  # choose a separator we can re-insert when keep-separator=false
  mut chosen_sep = ""
  for s in $seps {
    if $s == "" { continue }
    if (($src | split row $s | length) > 1) {
      $chosen_sep = $s
      break
    }
  }

  let pieces = (split_recurse $src $seps 0 $chunk_size $use_bytes $keep_sep)
  let chunks = (merge_chunks $pieces $chunk_size $overlap $use_bytes $keep_sep $chosen_sep)

  let chosen_sep = $chosen_sep
  let records = (
    $chunks | enumerate | each {|it|
      { content: ($it.item), meta: { chosen_separator: $chosen_sep, index: $it.index } }
    }
  )

  if $ndjson {
    $records | each {|r| $r | to json -r } | to text
  } else {
    $records
  }
}

# ---------- exported commands ----------
export def recursive-chunker [
  --chunk-size: int = 1000
  --overlap: int = 200
  --separators: list<string>   # e.g. ["\n\n" "\n" " " ""]
  --keep-separator
  --bytes
  --ndjson
  --text (-t): string
] {
  let use_bytes = ($bytes | default false)
  let keep_sep  = ($keep_separator | default false)
  let ndj       = ($ndjson | default false)
  let intext = $in
  let default_seps = [ "\n\n" "\n" " " "" ]
  let seps = (if ((($separators | default []) | is-empty)) { $default_seps } else { $separators })

  let src = if ((($text | default "") | is-empty)) { $intext | into string } else { $text }
  if ($src | is-empty) { return [] }

  run-chunker $src $seps $chunk_size $overlap $keep_sep $use_bytes $ndj
}

export def recursive-chunker-from-language [
  --language: string
  --chunk-size: int = 1000
  --overlap: int = 200
  --keep-separator
  --bytes
  --ndjson
  --text (-t): string
] {
  if (($language | default "" | is-empty)) {
    error make { msg: "Please provide --language (e.g., python, ts, markdown, html, latex, solidity…)" }
  }

  let intext = $in
  let use_bytes = ($bytes | default false)
  let keep_sep  = ($keep_separator | default false)
  let ndj       = ($ndjson | default false)

  let seps = (get-separators-for-language $language)
  let src = if ((($text | default "") | is-empty)) { $intext| into string } else { $text }
  if ($src | is-empty) { return [] }

  run-chunker $src $seps $chunk_size $overlap $keep_sep $use_bytes $ndj
}