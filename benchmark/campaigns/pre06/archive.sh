#!/usr/bin/env bash
# Archive and publish a Stage 2A evidence root (README.md, "Archive"). Linux, GNU tools.
#
#   archive.sh checksums ROOT
#       ROOT/checksums.sha256 over every regular file under ROOT but itself (the nested
#       julia-<V>/checksums.sha256 included), paths relative to ROOT, in C-locale order.
#   archive.sh pack ROOT FREEZE_SHA [--pilot-rehearsal]
#       checksums, then `campaign.py verify ROOT --archive --freeze-sha FREEZE_SHA`
#       (with --allow-pilot for a rehearsal), then, unless verify blocks, beside ROOT:
#       ROOT.tar.gz, ROOT.tar.gz.sha256, ROOT.tar.gz.status and ROOT.verify.out.
#       verify 0: packed, exit 0. verify 2: packed (valid evidence, NUMERICAL FAILURE,
#       never a healthy reference), exit 2. Anything else, or result lines that disagree
#       with the exit code: nothing packed, exit 1. Never overwrites an existing file.
#   archive.sh release ROOT FREEZE_SHA --tag TAG [--disposition REF]
#       official archives only: re-checks the packed archive and the freeze on GitHub,
#       then `gh release create TAG ROOT.tar.gz --target FREEZE_SHA`. Verify 2 needs
#       --disposition (the maintainer's recorded decision, e.g. an #110 comment URL).
#       Never overwrites, moves or deletes a tag, release or asset.
#
# CAMPAIGN (environment) is the campaign.py to run; default: the one beside this script.
# Its campaign.toml (same directory) gives the campaign id, pins and archive names.
set -euo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
CAMPAIGN=${CAMPAIGN:-$HERE/campaign.py}
ISSUE=110

die() { echo "archive.sh: $*" >&2; exit 1; }

# The campaign.toml values used here, tab-separated, from the freeze checkout's copy.
pins() {
  python3 -B -c '
import sys, tomllib
c = tomllib.load(open(sys.argv[1], "rb"))
a, s, b = c["archive"], c["proximalsolvers"], c["proximalbase"]
print("\t".join([c["campaign_id"], a["name"], a["asset"], a["release_tag"], a["repository"],
                 s["commit"], b["version"], b["tree"],
                 " and ".join(j["version"] for _, j in sorted(c["julia"].items()))]))
' "$(dirname "$CAMPAIGN")/campaign.toml"
}

# The physical path of directory $1, which must not itself be a symbolic link.
real_dir() {
  local dir=${1%/}
  [ -n "$dir" ] || dir=/
  [ ! -L "$dir" ] || die "$1 is a symbolic link; the root must be a real directory"
  (cd "$dir" && pwd -P) || die "no directory $1"
}

# Every member of tarball $1 is a regular file or directory under $2/ (no absolute
# path, no empty, '.' or '..' component, no duplicate). Listed by tar itself; returns 1.
check_members() {
  local tarball=$1 name=$2 types names line dups
  types=$(tar -tvzf "$tarball") && names=$(tar -tzf "$tarball") \
    || { echo "archive.sh: cannot list $tarball" >&2; return 1; }
  while IFS= read -r line; do
    case $line in -*|d*) ;;
      *) echo "archive.sh: $tarball: not a regular file or directory: '$line'" >&2; return 1 ;;
    esac
  done <<< "$types"
  while IFS= read -r line; do
    if [[ ! ( $line == "$name" || $line == "$name/"* ) || /${line%/}/ == *//* \
          || /${line%/}/ == */./* || /${line%/}/ == */../* ]]; then
      echo "archive.sh: $tarball: member path outside $name/: '$line'" >&2; return 1
    fi
  done <<< "$names"
  [ "$(wc -l <<< "$types")" = "$(wc -l <<< "$names")" ] \
    || { echo "archive.sh: $tarball: inconsistent listings" >&2; return 1; }
  dups=$(LC_ALL=C sort <<< "$names" | uniq -d)
  [ -z "$dups" ] || { echo "archive.sh: $tarball: duplicate members: $dups" >&2; return 1; }
}

checksums() {
  local root tmp
  root=$(real_dir "$1")
  rm -f "$root/checksums.sha256"
  local odd
  odd=$(cd "$root" && find . ! -type f ! -type d -printf '%P\n') || die "cannot list $root"
  [ -z "$odd" ] || die "not regular files or directories (links, FIFOs, sockets, devices): $odd"
  # sha256sum escapes these names, and the verifier rejects escaped lines
  odd=$(cd "$root" && find . -type f \( -path '*\\*' -o -path "*"$'\n'"*" \) -printf '%P\n') \
    || die "cannot list $root"
  [ -z "$odd" ] || die "file names with a backslash or newline cannot be listed: $odd"
  tmp=$(mktemp "$(dirname "$root")/.checksums.XXXXXX")   # outside ROOT: never listed
  if ( cd "$root" && find . -type f ! -path ./checksums.sha256 -printf '%P\0' |
         LC_ALL=C sort -z | xargs -0 -r sha256sum ) > "$tmp"; then
    chmod 0644 "$tmp"
    mv "$tmp" "$root/checksums.sha256"
  else
    rm -f "$tmp"
    die "checksum generation failed under $root; no checksums.sha256 written"
  fi
}

# Run verify on ROOT; sets verify_rc and writes its stdout to $2.
run_verify() {
  local root=$1 out=$2; shift 2
  verify_rc=0
  python3 -B "$CAMPAIGN" verify "$root" --archive "$@" > "$out" || verify_rc=$?
}

result_line() {   # the verify output line starting with $1
  grep -m1 "^$1: " "$2" || die "verify output $2 has no '$1:' line"
}

pack() {
  [ $# -ge 2 ] && [ $# -le 3 ] || die "usage: pack ROOT FREEZE_SHA [--pilot-rehearsal]"
  local root parent base sha=$2 mode=official extra=() tarball out
  [ $# -eq 2 ] || [ "$3" = --pilot-rehearsal ] || die "unknown option $3"
  [ $# -eq 2 ] || { mode=pilot-rehearsal; extra=(--allow-pilot); }
  [[ $sha =~ ^[0-9a-f]{40}$ ]] || die "FREEZE_SHA must be a full 40-hex commit"
  root=$(real_dir "$1")
  parent=$(dirname "$root") base=$(basename "$root")
  tarball=$parent/$base.tar.gz out=$parent/$base.verify.out
  [[ $tarball != *'#'* ]] || die "the archive path $tarball contains '#' (gh reads it as a label)"
  for f in "$tarball" "$tarball.sha256" "$tarball.status" "$out"; do
    [ ! -e "$f" ] || die "$f exists; never overwritten (move it away after reading it)"
  done
  local id pins_line
  pins_line=$(pins) || die "cannot read campaign.toml beside $CAMPAIGN"
  id=${pins_line%%$'\t'*}

  checksums "$root"
  run_verify "$root" "$out" --freeze-sha "$sha" ${extra[@]+"${extra[@]}"}
  local numerical evidence_want=OFFICIAL
  case $verify_rc in
    0) numerical="all cases certified ok" ;;
    2) numerical="NUMERICAL FAILURE: valid archived evidence, not a healthy reference" ;;
    *) die "verify exited with $verify_rc (see $out): integrity or execution failure; not packed" ;;
  esac
  [ "$mode" = official ] || evidence_want="PILOT / NON-OFFICIAL"
  local integrity numline hardware evidence
  integrity=$(result_line "RECORD INTEGRITY" "$out")
  numline=$(result_line NUMERICAL "$out")
  hardware=$(result_line HARDWARE "$out")
  evidence=$(result_line EVIDENCE "$out")
  [ "$integrity" = "RECORD INTEGRITY: PASS" ] || die "verify exit $verify_rc but '$integrity'"
  case $verify_rc:$numline in 0:"NUMERICAL: PASS"*|2:"NUMERICAL: FAIL"*) ;;
    *) die "verify exit $verify_rc but '$numline'" ;; esac
  case $evidence in "EVIDENCE: $evidence_want"*) ;;
    *) die "a $mode pack but verify says '$evidence'" ;; esac

  # Never -h: links are refused above; hard links are stored as file contents.
  tar -C "$parent" --hard-dereference -czf "$tarball.partial" "$base" \
    || { rm -f "$tarball.partial"; die "tar failed"; }
  check_members "$tarball.partial" "$base" \
    || { rm -f "$tarball.partial"; die "the tarball holds more than regular files and directories; not packed"; }
  mv "$tarball.partial" "$tarball"
  local digest
  digest=$(sha256sum "$tarball") || die "cannot hash $tarball"
  digest=${digest%% *}
  echo "$digest  $base.tar.gz" > "$tarball.sha256"
  printf '%s\n' "campaign_id: $id" "mode: $mode" "freeze_sha: $sha" "verify_rc: $verify_rc" \
    "numerical_status: $numerical" "$integrity" "$numline" "$hardware" "$evidence" \
    "archive_sha256: $digest" > "$tarball.status"
  echo "archive: $tarball"
  echo "sha256:  $digest"
  cat "$tarball.status"
  if [ "$verify_rc" -eq 2 ]; then
    echo "*** $numerical ***" >&2
    exit 2
  fi
}

status_value() {   # the value of key $1 in the status file $2
  local line
  line=$(grep -m1 "^$1: " "$2") || die "$2 has no '$1:' line"
  echo "${line#"$1: "}"
}

release() {
  [ $# -ge 2 ] || die "usage: release ROOT FREEZE_SHA --tag TAG [--disposition REF]"
  local root parent base sha=$2 tag="" disposition="" tarball status
  root=$(real_dir "$1")
  shift 2
  while [ $# -gt 0 ]; do
    case $1 in
      --tag) [ $# -ge 2 ] || die "--tag needs a value"; tag=$2; shift 2 ;;
      --disposition) [ $# -ge 2 ] || die "--disposition needs a value"; disposition=$2; shift 2 ;;
      *) die "unknown argument $1" ;;
    esac
  done
  [ -n "$tag" ] || die "release needs --tag"
  [[ $sha =~ ^[0-9a-f]{40}$ ]] || die "FREEZE_SHA must be a full 40-hex commit"
  parent=$(dirname "$root") base=$(basename "$root")
  tarball=$parent/$base.tar.gz status=$tarball.status

  local pins_line id name asset release_tag repo ps_commit pb_version pb_tree julias
  pins_line=$(pins) || die "cannot read campaign.toml beside $CAMPAIGN"
  IFS=$'\t' read -r id name asset release_tag repo ps_commit pb_version pb_tree julias <<< "$pins_line"
  [ "$base" = "$name" ] || die "root $base is not the official archive $name"
  [ "$asset" = "$name.tar.gz" ] || die "campaign.toml: asset $asset is not $name.tar.gz"
  [[ $tarball != *'#'* ]] || die "the archive path $tarball contains '#' (gh reads it as a label)"
  if [ -n "$disposition" ]; then
    [[ $disposition != *$'\n'* ]] || die "--disposition must be a single line"
    local issue_url="https://github.com/$repo/issues/$ISSUE#issuecomment-"
    if [[ $disposition == *://* || $disposition == *github.com* ]]; then
      [[ $disposition == "$issue_url"* && ${disposition#"$issue_url"} =~ ^[0-9]+$ ]] \
        || die "--disposition URL must be $issue_url<digits>"
    fi
  fi
  local notes=$parent/$base.release-notes.md
  [ ! -e "$notes" ] || die "$notes exists; never overwritten (move it away after reading it)"
  [ "$tag" = "$release_tag" ] || die "tag $tag is not the campaign's release tag $release_tag"

  # The packed archive: present, its digest recomputed, its status official and acceptable.
  [ -f "$tarball" ] && [ -f "$tarball.sha256" ] && [ -f "$status" ] \
    || die "pack first: $tarball, .sha256 and .status are required"
  local digest
  digest=$(sha256sum "$tarball") || die "cannot hash $tarball"
  digest=${digest%% *}
  [ "$(cat "$tarball.sha256")" = "$digest  $asset" ] || die "$tarball does not match its .sha256"
  [ "$(status_value archive_sha256 "$status")" = "$digest" ] || die "$status names another archive"
  [ "$(status_value mode "$status")" = official ] \
    || die "$status is not an official archive (a pilot rehearsal is never released)"
  [ "$(status_value campaign_id "$status")" = "$id" ] || die "$status is of another campaign"
  [ "$(status_value freeze_sha "$status")" = "$sha" ] || die "$status was packed at another freeze"
  local packed_rc
  packed_rc=$(status_value verify_rc "$status")

  # Verify the archive's own content (extracted), officially: no --allow-pilot.
  scratch=$(mktemp -d "$parent/.release-check.XXXXXX")   # global: the EXIT trap uses it
  trap 'rm -rf -- "$scratch"' EXIT
  check_members "$tarball" "$base" || die "$tarball holds more than $base/ files and directories; not extracted"
  tar -C "$scratch" --keep-old-files --no-same-owner -xzf "$tarball" || die "cannot extract $tarball"
  run_verify "$scratch/$base" "$scratch/verify.out" --freeze-sha "$sha"
  [ "$verify_rc" = "$packed_rc" ] || die "verify of the archive exits $verify_rc; packed with $packed_rc"
  case $verify_rc in
    0) ;;
    2) [ -n "$disposition" ] || die "NUMERICAL FAILURE archive: release needs --disposition REF (the maintainer's recorded decision); archive kept, nothing released" ;;
    *) die "verify of the archive exited with $verify_rc; not released" ;;
  esac
  [ "$(result_line EVIDENCE "$scratch/verify.out")" = "EVIDENCE: OFFICIAL" ] \
    || die "verify does not label the archive OFFICIAL; not released"
  local integrity numline hardware label
  integrity=$(result_line "RECORD INTEGRITY" "$status")
  numline=$(result_line NUMERICAL "$status")
  hardware=$(result_line HARDWARE "$status")
  for label in "RECORD INTEGRITY" NUMERICAL HARDWARE; do
    [ "$(result_line "$label" "$scratch/verify.out")" = "$(result_line "$label" "$status")" ] \
      || die "verify of the archive and $status disagree on $label"
  done

  # The freeze commit on GitHub: exists, reachable from master, recorded on #110.
  local out
  out=$(gh api "repos/$repo/commits/$sha" --jq .sha) || die "gh: freeze commit $sha not found on $repo"
  [ "$out" = "$sha" ] || die "gh: $repo resolves $sha to '$out'"
  out=$(gh api "repos/$repo/compare/master...$sha" --jq .status) || die "gh: cannot compare master...$sha"
  case $out in identical|behind) ;; *) die "freeze commit is not reachable from master (status '$out')" ;; esac
  out=$(gh issue view "$ISSUE" --repo "$repo" --json comments --jq '.comments[].body') \
    || die "gh: cannot read the comments of #$ISSUE"
  grep -qF -- "$sha" <<< "$out" || die "freeze commit $sha is not recorded in a comment on #$ISSUE"
  # Tag and release must not exist; only a definite "not found" counts as absent.
  if out=$(gh api "repos/$repo/git/ref/tags/$tag" 2>&1); then
    die "tag $tag already exists; never move it (a correction is a new campaign and tag)"
  fi
  grep -q 'HTTP 404' <<< "$out" || die "gh: cannot tell whether tag $tag exists: $out"
  if out=$(gh release view "$tag" --repo "$repo" 2>&1); then
    die "release $tag already exists; never overwrite it"
  fi
  grep -qi 'release not found' <<< "$out" || die "gh: cannot tell whether release $tag exists: $out"

  local failure=""
  if [ "$verify_rc" -eq 2 ]; then
    failure="> **NUMERICAL FAILURE: valid archived evidence with non-ok cases; NOT a healthy
> baseline or reference.** Maintainer disposition: $disposition
"
  fi
  (set -o noclobber; cat > "$notes") <<EOF
Benchmark evidence archive for #$ISSUE; **not a Julia package release** of ProximalSolvers.jl.

${failure}
- Campaign: \`$id\` (Stage 2A pre-0.6 baseline), https://github.com/$repo/issues/$ISSUE
- Freeze commit: \`$sha\`
- Measured ProximalSolvers commit: \`$ps_commit\`
- ProximalBase $pb_version, registered release tree \`$pb_tree\`
- Julia $julias (separate environments, records and reports)
- $integrity
- $numline
- $hardware
- Evidence: OFFICIAL
- Asset \`$asset\`, SHA-256 \`$digest\`; kept permanently and never replaced (a correction
  is a new campaign and tag).

Re-verify: README.md of benchmark/campaigns/pre06 at the freeze commit, "Retrieve and re-verify".
EOF
  gh release create "$tag" "$tarball" --repo "$repo" --target "$sha" --latest=false \
    --title "Stage 2A $id (benchmark evidence, not a package release)" --notes-file "$notes" \
    || die "gh release create failed; check $repo for a partial release before anything else"
  echo "released $tag: $asset sha256 $digest"
}

[ $# -ge 1 ] || die "usage: archive.sh checksums|pack|release ..."
command=$1; shift
case $command in
  checksums) [ $# -eq 1 ] || die "usage: checksums ROOT"; checksums "$1" ;;
  pack) pack "$@" ;;
  release) release "$@" ;;
  *) die "unknown command $command" ;;
esac
