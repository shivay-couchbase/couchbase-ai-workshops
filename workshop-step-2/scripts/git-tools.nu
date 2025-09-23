
export def git_log [] {
   let logs = git log --all --pretty=format:'%n{%n"branch": "%d",%n  "commit_hash": "%H",%n  "author": "%an",%n  "author_email": "%ae",%n  "date": "%ad",%n  "commiter_name": "%cN",%n  "commiter_email": "%cE",%n  "message": "%f",%n "body": "%b"%n}' | lines | find --regex "^origin" --invert | str replace "}" "}," | append "]" | prepend "[" | drop nth 3 | to text | from json
   $logs | save -f commitlog.json
}

# git_log_to_json.nu
export def git_log [
  --include-patch(-p) # also include the full unified diff as text per commit
  --out(-o): string = "commitlog.json" # output file
] {
  # 1) Collect commit metadata in a structured table
  let commits = (git log --all --date=iso-strict --pretty=format:'%H|%D|%an|%ae|%cN|%cE|%ad|%s|%b' |
    lines |
    each {|l|
      let p = ($l | split row '|' )
      {
        hash:            ($p | get 0)
        refs:            ($p | get 1)
        author:          ($p | get 2)
        author_email:    ($p | get 3)
        committer:       ($p | get 4)
        committer_email: ($p | get 5)
        date:            ($p | get 6)
        subject:         ($p | get 7)
        body:            ($p | get 8)
      }
    }
  )

  # 2) Enrich each commit with file-level stats (+added, -deleted, status) and optional patch
  let enriched = ($commits | each {|c|
    # a) numstat: added, deleted, path (handles '-' for binary)
    let numstat = (
      git show --no-color --numstat --format='' $c.hash
      | lines
      | where {|x| $x != '' }
      | parse --regex '(?<added>\d+|\-)\s+(?<deleted>\d+|\-)\s+(?<path>.+)'
      | update added {|r| if $r.added  == '-' { null } else { ($r.added  | into int) } }
      | update deleted {|r| if $r.deleted == '-' { null } else { ($r.deleted | into int) } }
    )

    # b) name-status: A/M/D/R/C/T/U/? codes (first column)
    let status_rows = (
      git show --no-color --name-status --format='' $c.hash
      | lines
      | where {|x| $x != '' }
      | parse --regex '(?<status>[A-Z\?])\s+(?<path>.+)'
    )

    # c) build a map path -> status for quick lookups
    let status_map = ($status_rows | reduce -f {} {|row, acc| $acc | insert $row.path $row.status })

    # d) combine stats + status into files array
    let files = (
      $numstat | default [] | each {|f|
        let st = ($status_map | get -i $f.path)
        { path: $f.path, added: $f.added, deleted: $f.deleted, status: ($st | default 'M') }
      }
    )

    # e) optional unified patch text for the commit
    let patch_text = (if $include_patch {
      git show --no-color -p --format='' $c.hash | str trim
    } else { null })

    $c | merge { files: $files, patch: $patch_text }
  })

  # 3) Save as compact JSON array
  $enriched | to json -r | save -f $out
}


def gh_import_issues [] {

# npx repomix@latest --parsable-style
# gh api --paginate repos/couchbaselabs/couchbase-shell/pulls?per_page=100

}



# Download every repository PRs. Must have Github official CLI installed and configured 
def gh_download_issues [
  repoPath: string # Path to the github repository
] {
  mut issues = ( gh api --paginate $"repos/($repoPath)/issues?per_page=100&state=all"  | from json )
  for issue in $issues {
    let docId = $"issue::($issue.number)"
    mut $d = $docId | doc get | get 0
    mut docExist = true
    if ( $d |$d.cas ==  0) {
      doc upsert $docId $issue
      $d = $docId | doc get | get 0
    mut docExist = true
    }
    # Update comments
    if ( ( not $docExist ) or ( $d.content.comments < $issue.comments )) {
      let comments = ( gh api --paginate $issue.comments_url | from json ) 
      for comment in $comments {
        let commendId = $"($docId)::comment::($comment.id)"
        doc upsert $commendId $comment
      }
    }
    
    doc upsert $docId $issue
  }
}


# Download every repository PRs. Must have Github official CLI installed and configured 
def gh_download_prs [
  repoPath: string # Path to the github repository
] {
  mut prs = ( gh api --paginate $"repos/($repoPath)/pulls?per_page=100"  | from json )
  for pr in $prs {
    let docId = $"pull::($pr.number)"
    mut $d = $docId | doc get | get 0
    mut docExist = true
    if ( $d.cas ==  0) {
      doc upsert $docId $pr
      $d = $docId | doc get | get 0
      mut docExist = false
    }
    # Get Code with gh api $pr.diff_url
    # pr.review_comments_url

    # Update comments
    if ( ( not $docExist ) or ( $d.content.comments? < $pr.comments? ) ) {
      let comments = ( gh api --paginate $pr.comments_url | from json ) 
      for comment in $comments {
        let commendId = $"($docId)::comment::($comment.id)"
        doc upsert $commendId $comment
      }
    }
    doc upsert $docId $pr
  }
}

def summarize_pr [] {
    let title = ($in.title | default "No title")
    let number = ($in.number | default "N/A")
    let state = ($in.state | default "unknown")
    let merged = ($in.merged | default false)
    let author = ($in.user.login | default "unknown")
    let reviewers = ($in.requested_reviewers | get login | str join ", " | default "none")
    let created = ($in.created_at | default "")
    let merged_at = ($in.merged_at | default "")
    let commits = ($in.commits | default 0)
    let files_changed = ($in.changed_files | default 0)
    let additions = ($in.additions | default 0)
    let deletions = ($in.deletions | default 0)
    let body = ($in.body | default "")

    let status = if $merged { "merged" } else { $state }

    
    let body_summary = ($body | str replace "\r" " " | str replace "\n" " " )

    let summary =  $"
Pull Request #($number): ($title)
Author: ($author)
Reviewers: ($reviewers)
Created: ($created), Merged: ($merged_at)
Status: ($status)

Motivation & Changes:
($body_summary)

Stats: ($commits) commit\(s\), ($files_changed) files changed, +($additions)/-($deletions) lines
URL: ($in.html_url)
"
    $summary
}


def import_gh_repo [
  repoPath: string # Path to the github repository
  ] {
  cb-env bucket "repositories"
  cb-env scope "_default"
  let repoId = $repoPath | str replace "/" "_"
  if ( collections | where collection == $repoId | is-empty ) {
    collections create $repoId
  }
  cb-env collection $repoId
  gh_download_issues $repoPath
  gh_download_prs $repoPath
}

# summarize_pr_comments_threaded.nu
# Usage: open comments.json | source summarize_pr_comments_threaded.nu | summarize_pr_comments_threaded

def summarize_pr_comments_threaded [] {
    # group comments by thread (top-level comment has no in_reply_to_id)
    let grouped = (
        $in 
        | group-by { |c| ($c.in_reply_to_id? | default $c.id) }
    )

    let summaries = $grouped | each {|thread|
        let comments = $thread | values | get 0
        let code = ($comments.0.diff_hunk | default "")

      let s1 =  $"
───────────────────────────────
Code context:
($code)

Thread:
"

        let s2 = $comments | each {|c|
            let author = ($c.user.login | default "unknown")
            let file = ($c.path | default "unknown file")
            let line = ($c.line | default "")
            let body = ($c.body | str replace "\r" " " | str replace "\n" " ")
            let created = ($c.created_at | default "")
            let url = ($c.html_url | default "")

            $"- ($author) on ($file):($line) at ($created)
  ($body)
  Link: ($url)
"
        }
      $"($s1)\n($s2 | str join "\n")"
    }
$summaries
  }
