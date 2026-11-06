#!/usr/bin/env bash
# Archive and publish a Stage 2A evidence root (README.md, "Archive"). Linux, GNU tools.
#
#   archive.sh checksums ROOT
#       ROOT/checksums.sha256 over every regular file under ROOT but itself (the nested
#       julia-<V>/checksums.sha256 included), paths relative to ROOT, in C-locale order.
#   archive.sh pack ROOT FREEZE_SHA [--pilot-rehearsal]
#       checksums, then `campaign.py verify ROOT --archive --freeze-sha FREEZE_SHA`
#       (with --allow-pilot for a rehearsal); unless verify blocks, the tarball is built
#       in a private staging directory, its members checked, and the same verify run on
#       its extracted copy. Then, beside ROOT: ROOT.tar.gz, ROOT.tar.gz.sha256 and
#       ROOT.tar.gz.status (ROOT.verify.out in every case). verify 0: exit 0. verify 2:
#       packed (valid evidence, NUMERICAL FAILURE, never a healthy reference), exit 2.
#       Anything else, or result lines that disagree with the exit code: nothing packed,
#       exit 1. Never overwrites or writes through an existing file or link.
#   archive.sh release ROOT FREEZE_SHA --tag TAG [--disposition REF]
#       official archives only: copies the tarball once into a private staging directory
#       and works only on that copy (digest, members, extracted verify, upload); checks
#       the freeze on GitHub; creates the tag ref at FREEZE_SHA through the API (fails if
#       it exists), re-reads it, then `gh release create TAG <copy> --verify-tag`.
#       Verify 2 needs --disposition (the maintainer's recorded decision, e.g. an #110
#       comment URL). Never overwrites, moves or deletes a tag, release or asset: a tag
#       left by a failed `gh release create` is reported and left to the maintainer.
#
# CAMPAIGN (environment) is the campaign.py that pack runs; default: the one beside this
# script, whose campaign.toml gives the campaign id, pins and archive names. `release`
# ignores a CAMPAIGN override (a stub verify must never approve a real release) unless
# ARCHIVE_SH_ALLOW_STUB=1, which only the offline tests (test_campaign.py) set.
# Every tar runs without TAR_OPTIONS and GZIP from the environment.
#
# Threat model: the root's parent directory and the staging directories in it are assumed
# not to be modified concurrently by untrusted local processes. Integrity does not rely on
# directory permissions but on the checksums, the verify of the extracted tarball, the
# re-hash of the staged copy before the upload and the re-read of the tag at FREEZE_SHA. A
# hostile concurrent writer in the same directory can still race a check and the `ln` or
# `rm` that follows it (out of scope); that never leads to publishing unverified bytes.
# `checksums` is pinned to the root's inode; `pack` addresses the root by name for verify
# and tar, where a swap is caught by the member check and the extracted-tarball verify.
set -euo pipefail
unset CDPATH

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
DEFAULT_CAMPAIGN=$HERE/campaign.py
CAMPAIGN=${CAMPAIGN:-$DEFAULT_CAMPAIGN}
ISSUE=110
stage=""   # the private staging directory of pack or release; removed on exit
installed=()     # pack: "destination<TAB>staged source" of each sidecar or tarball installed
committed=no     # pack: yes once the tarball is installed (then nothing is rolled back)

die() { echo "archive.sh: $*" >&2; exit 1; }
warn() { echo "archive.sh: warning: $*" >&2; }
tar_() { env -u TAR_OPTIONS -u GZIP tar "$@"; }

# Removing the staging directory never changes the exit status (it may hold read-only
# directories of the evidence, and gh release create may already have succeeded).
cleanup() {
  [ -n "$stage" ] || return 0
  if [ -L "$stage" ]; then   # swapped for a link: never follow it (chmod would)
    warn "$stage is now a symbolic link; left in place"
    return 0
  fi
  [ -d "$stage" ] || return 0
  # Make its directories removable without following links (find does not follow them);
  # runs under set +e (the EXIT trap); rm decides.
  find "$stage" -type d -exec chmod u+rwx -- {} +
  if ! rm -rf -- "$stage"; then
    warn "could not remove $stage"
  fi
}
# An unfinished pack removes the files it installed, in one pass, each only if it is still
# its own (the same inode as the staged file, not a link), checked immediately before its
# `rm`; nothing else is ever removed. The window between that check and the `rm` is the
# residual race of the threat model above.
rollback() {
  [ "$committed" = no ] || return 0
  local entry dest source
  for entry in ${installed[@]+"${installed[@]}"}; do
    dest=${entry%%$'\t'*} source=${entry#*$'\t'}
    if [ "$dest" -ef "$source" ] && [ ! -L "$dest" ]; then
      rm -f -- "$dest"
    fi
  done
}
trap 'rc=$?; set +e; rollback; cleanup; exit "$rc"' EXIT

make_stage() {   # a private (0700) directory beside the root, outside it
  stage=$(mktemp -d "$1/.archive-stage.XXXXXX") || die "cannot create a staging directory in $1"
}

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

# The physical path of directory $1, which must not itself be a symbolic link, however
# it is spelled (LINK, LINK/, LINK//, LINK/.).
real_dir() {
  local logical trimmed=$1
  while [[ $trimmed == */ ]]; do trimmed=${trimmed%/}; done
  case $trimmed in ""|.|..) die "ROOT '$1' must name an evidence directory (not empty, /, . or ..)" ;; esac
  logical=$(cd -L -- "$1" && pwd -L) || die "no directory $1"
  [ ! -L "$logical" ] || die "$1 is a symbolic link; the root must be a real directory"
  local physical here
  # Canonical physical paths: realpath also collapses the leading // that bash keeps.
  physical=$(realpath -e -- "$logical") || die "no directory $1"
  here=$(realpath -e -- .) || die "cannot resolve the current directory"
  # `/`, the current directory or one of its ancestors, however spelled (./., sub/.., //./)
  [[ $here/ != "${physical%/}/"* ]] \
    || die "ROOT '$1' is $physical: /, the current directory or one of its ancestors"
  echo "$physical"
}

absent() {   # refuse an existing destination, also a dangling symbolic link
  local f
  for f in "$@"; do
    [ ! -e "$f" ] && [ ! -L "$f" ] || die "$f exists; never overwritten (move it away after reading it)"
  done
}

# Hard-link staged $1 to $2: fails if $2 exists in any form (-T: never into a directory
# or through a link to one), then checks that $2 is that very file.
install_new() {
  ln -T -- "$1" "$2" || die "cannot install $2 (it must not exist)"
  [ -f "$2" ] && [ ! -L "$2" ] && [ "$2" -ef "$1" ] || die "$2 is not the file installed"
}

# Every member of tarball $1 is a regular file or directory under $2/ (no absolute
# path, no empty, '.' or '..' component, no duplicate). Listed by tar itself; returns 1.
check_members() {
  local tarball=$1 name=$2 types names line dups
  types=$(tar_ -tvzf "$tarball") && names=$(tar_ -tzf "$tarball") \
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

extract() {   # tarball $1 into the new directory $2; links were refused by check_members
  mkdir -- "$2" && tar_ -C "$2" --keep-old-files --no-same-owner -xzf "$1"
}

checksums() {
  local root tmp
  root=$(real_dir "$1")
  [ -n "$stage" ] || make_stage "$(dirname "$root")"   # pack's stage, or its own
  tmp=$stage/checksums.sha256   # outside ROOT: never listed; removed with the stage
  # Pinned to the root's inode: one subshell whose working directory is the root (checked
  # after `cd -P`), using relative paths only, so a rename or link swap of the root's
  # name after its resolution cannot redirect the removal, the scan or the install.
  (
    cd -P -- "$root" || die "no directory $root"
    [ "$(pwd -P)" = "$root" ] || die "$root changed after its resolution; nothing written"
    rm -f ./checksums.sha256
    odd=$(find . ! -type f ! -type d -printf '%P\n') || die "cannot list $root"
    [ -z "$odd" ] || die "not regular files or directories (links, FIFOs, sockets, devices): $odd"
    # sha256sum escapes these names, and the verifier rejects escaped lines
    odd=$(find . -type f \( -path '*\\*' -o -path "*"$'\n'"*" -o -path "*"$'\r'"*" \) \
          -printf '%P\n') || die "cannot list $root"
    [ -z "$odd" ] || die "file names with a backslash, newline or carriage return cannot be listed: $odd"
    find . -type f ! -path ./checksums.sha256 -printf '%P\0' | LC_ALL=C sort -z \
      | xargs -0 -r sha256sum > "$tmp" \
      || die "checksum generation failed under $root; no checksums.sha256 written"
    # any escaped name: the verifier would reject the list
    ! grep -q '^\\' "$tmp" || die "sha256sum escaped a file name under $root; no checksums.sha256 written"
    chmod 0644 "$tmp"
    install_new "$tmp" ./checksums.sha256
    [ ./checksums.sha256 -ef "$tmp" ] || die "$root/checksums.sha256 is not the list installed"
  )
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
  absent "$tarball" "$tarball.sha256" "$tarball.status" "$out"
  local id pins_line
  pins_line=$(pins) || die "cannot read campaign.toml beside $CAMPAIGN"
  id=${pins_line%%$'\t'*}

  make_stage "$parent"
  checksums "$root"
  run_verify "$root" "$stage/verify.out" --freeze-sha "$sha" ${extra[@]+"${extra[@]}"}
  install_new "$stage/verify.out" "$out"
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

  # Build and check the tarball in the staging directory. Never -h: links are refused
  # above; hard links are stored as file contents.
  local staged=$stage/$base.tar.gz label
  tar_ -C "$parent" --hard-dereference -czf "$staged" -- "$base" || die "tar failed; not packed"
  check_members "$staged" "$base" \
    || die "the tarball holds more than regular files and directories; not packed"
  # The tarball must reproduce the verified tree: the same verify on its extracted copy.
  extract "$staged" "$stage/extracted" || die "cannot extract the new tarball; not packed"
  local first_rc=$verify_rc
  run_verify "$stage/extracted/$base" "$stage/verify-archive.out" --freeze-sha "$sha" \
    ${extra[@]+"${extra[@]}"}
  [ "$verify_rc" = "$first_rc" ] \
    || die "verify of the tarball exits $verify_rc, of the root $first_rc; not packed"
  for label in "RECORD INTEGRITY" NUMERICAL HARDWARE EVIDENCE; do
    [ "$(result_line "$label" "$stage/verify-archive.out")" = "$(result_line "$label" "$out")" ] \
      || die "verify of the tarball and of the root disagree on $label; not packed"
  done

  local digest
  digest=$(sha256sum "$staged") || die "cannot hash $staged"
  digest=${digest%% *}
  echo "$digest  $base.tar.gz" > "$stage/sha256"
  printf '%s\n' "campaign_id: $id" "mode: $mode" "freeze_sha: $sha" "verify_rc: $verify_rc" \
    "numerical_status: $numerical" "$integrity" "$numline" "$hardware" "$evidence" \
    "archive_sha256: $digest" > "$stage/status"
  # Sidecars first, the tarball last: a tarball beside the root always has its sidecars,
  # and if any install fails, the files this run installed are removed (rollback).
  installed+=("$tarball.sha256"$'\t'"$stage/sha256")
  install_new "$stage/sha256" "$tarball.sha256"
  installed+=("$tarball.status"$'\t'"$stage/status")
  install_new "$stage/status" "$tarball.status"
  installed+=("$tarball"$'\t'"$staged")
  install_new "$staged" "$tarball"
  committed=yes
  # Packed. The summary is best effort (`|| true`: a closed or full stdout must not turn a
  # complete archive into a failure); the exit code is verify's, 0 or 2.
  trap '' PIPE
  set +e
  { echo "archive: $tarball"; echo "sha256:  $digest"; cat -- "$tarball.status"; } || true
  if [ "$verify_rc" -eq 2 ]; then
    echo "*** $numerical ***" >&2 || true
    exit 2
  fi
  exit 0
}

status_value() {   # the value of key $1 in the status file $2
  local line
  line=$(grep -m1 "^$1: " "$2") || die "$2 has no '$1:' line"
  echo "${line#"$1: "}"
}

release() {
  [ $# -ge 2 ] || die "usage: release ROOT FREEZE_SHA --tag TAG [--disposition REF]"
  local root parent base sha=$2 tag="" disposition="" given_disposition=no tarball
  root=$(real_dir "$1")
  shift 2
  while [ $# -gt 0 ]; do
    case $1 in
      --tag) [ $# -ge 2 ] || die "--tag needs a value"; tag=$2; shift 2 ;;
      --disposition) [ $# -ge 2 ] || die "--disposition needs a value"
                     disposition=$2 given_disposition=yes; shift 2 ;;
      *) die "unknown argument $1" ;;
    esac
  done
  [ -n "$tag" ] || die "release needs --tag"
  [[ $sha =~ ^[0-9a-f]{40}$ ]] || die "FREEZE_SHA must be a full 40-hex commit"
  if [ "$CAMPAIGN" != "$DEFAULT_CAMPAIGN" ] && [ "${ARCHIVE_SH_ALLOW_STUB:-}" != 1 ]; then
    warn "release ignores CAMPAIGN=$CAMPAIGN and runs $DEFAULT_CAMPAIGN"
    CAMPAIGN=$DEFAULT_CAMPAIGN
  fi
  parent=$(dirname "$root") base=$(basename "$root")
  tarball=$parent/$base.tar.gz

  local pins_line id name asset release_tag repo ps_commit pb_version pb_tree julias
  pins_line=$(pins) || die "cannot read campaign.toml beside $CAMPAIGN"
  IFS=$'\t' read -r id name asset release_tag repo ps_commit pb_version pb_tree julias <<< "$pins_line"
  [ "$base" = "$name" ] || die "root $base is not the official archive $name"
  [ "$asset" = "$name.tar.gz" ] || die "campaign.toml: asset $asset is not $name.tar.gz"
  [[ $tarball != *'#'* ]] || die "the archive path $tarball contains '#' (gh reads it as a label)"
  if [ "$given_disposition" = yes ]; then
    [[ $disposition =~ [^[:space:]] ]] || die "--disposition must not be empty or blank"
    [[ $disposition != *$'\n'* ]] || die "--disposition must be a single line"
    local issue_url="https://github.com/$repo/issues/$ISSUE#issuecomment-"
    if [[ $disposition == *://* || $disposition == *github.com* ]]; then
      [[ $disposition == "$issue_url"* && ${disposition#"$issue_url"} =~ ^[0-9]+$ ]] \
        || die "--disposition URL must be $issue_url<digits>"
    fi
  fi
  local notes=$parent/$base.release-notes.md
  absent "$notes"
  [ "$tag" = "$release_tag" ] || die "tag $tag is not the campaign's release tag $release_tag"

  # The packed archive, copied once into the staging directory; everything below uses
  # only that copy, so the bytes verified are the bytes uploaded.
  local f
  for f in "$tarball" "$tarball.sha256" "$tarball.status"; do
    [ -f "$f" ] && [ ! -L "$f" ] || die "pack first: $f must be a regular file"
  done
  make_stage "$parent"
  local staged=$stage/$asset status=$stage/status
  cp -- "$tarball" "$staged" && cp -- "$tarball.sha256" "$stage/sha256" \
    && cp -- "$tarball.status" "$status" || die "cannot copy the archive into $stage"
  local digest
  digest=$(sha256sum "$staged") || die "cannot hash $staged"
  digest=${digest%% *}
  [ "$(cat "$stage/sha256")" = "$digest  $asset" ] || die "$tarball does not match its .sha256"
  [ "$(status_value archive_sha256 "$status")" = "$digest" ] || die "$tarball.status names another archive"
  [ "$(status_value mode "$status")" = official ] \
    || die "$tarball.status is not an official archive (a pilot rehearsal is never released)"
  [ "$(status_value campaign_id "$status")" = "$id" ] || die "$tarball.status is of another campaign"
  [ "$(status_value freeze_sha "$status")" = "$sha" ] || die "$tarball.status was packed at another freeze"
  local packed_rc
  packed_rc=$(status_value verify_rc "$status")

  # Verify the archive's own content (extracted), officially: no --allow-pilot.
  check_members "$staged" "$base" || die "$tarball holds more than $base/ files and directories; not extracted"
  extract "$staged" "$stage/extracted" || die "cannot extract $tarball"
  run_verify "$stage/extracted/$base" "$stage/verify.out" --freeze-sha "$sha"
  [ "$verify_rc" = "$packed_rc" ] || die "verify of the archive exits $verify_rc; packed with $packed_rc"
  case $verify_rc in
    0) ;;
    2) [ -n "$disposition" ] || die "NUMERICAL FAILURE archive: release needs --disposition REF (the maintainer's recorded decision); archive kept, nothing released" ;;
    *) die "verify of the archive exited with $verify_rc; not released" ;;
  esac
  [ "$(result_line EVIDENCE "$stage/verify.out")" = "EVIDENCE: OFFICIAL" ] \
    || die "verify does not label the archive OFFICIAL; not released"
  local integrity numline hardware label
  integrity=$(result_line "RECORD INTEGRITY" "$status")
  numline=$(result_line NUMERICAL "$status")
  hardware=$(result_line HARDWARE "$status")
  for label in "RECORD INTEGRITY" NUMERICAL HARDWARE; do
    [ "$(result_line "$label" "$stage/verify.out")" = "$(result_line "$label" "$status")" ] \
      || die "verify of the archive and $tarball.status disagree on $label"
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
  cat > "$stage/notes.md" <<EOF
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
  install_new "$stage/notes.md" "$notes"
  # The staged copy, unchanged since it was verified, is what gh uploads.
  local final
  final=$(sha256sum "$staged") || die "cannot hash $staged"
  [ "${final%% *}" = "$digest" ] || die "the staged archive changed after verification; not released"
  # The tag, created atomically at the freeze commit (the API refuses an existing ref),
  # then re-read; `--verify-tag` makes gh use that tag and never create one elsewhere.
  gh api -X POST "repos/$repo/git/refs" -f "ref=refs/tags/$tag" -f "sha=$sha" > /dev/null \
    || die "gh: cannot create tag $tag at $sha; nothing released. Check whether tag $tag exists on $repo and at which commit; tags are never moved or deleted automatically"
  local left="tag $tag now exists on $repo (created by this run at $sha); it is never moved or
  deleted automatically: inspect it, then publish its release by hand or remove it by hand"
  out=$(gh api "repos/$repo/git/ref/tags/$tag" --jq '.object.type + " " + .object.sha') \
    || die "gh: cannot re-read tag $tag; nothing released; $left"
  [ "$out" = "commit $sha" ] || die "tag $tag is '$out', not commit $sha; nothing released; $left"
  gh release create "$tag" "$staged" --repo "$repo" --verify-tag --latest=false \
    --title "Stage 2A $id (benchmark evidence, not a package release)" --notes-file "$stage/notes.md" \
    > "$stage/created.out" || die "gh release create failed; check $repo for a partial release; $left"
  # Released: irreversible. Nothing after this may change the exit status, not even a
  # closed or full stdout, so the message is best effort.
  trap '' PIPE
  set +e
  # Messages after an irreversible success: `|| true` keeps a closed stdout from failing it.
  cat -- "$stage/created.out" || true
  echo "released $tag: $asset sha256 $digest" || true
  exit 0
}

[ $# -ge 1 ] || die "usage: archive.sh checksums|pack|release ..."
command=$1; shift
case $command in
  checksums) [ $# -eq 1 ] || die "usage: checksums ROOT"; checksums "$1" ;;
  pack) pack "$@" ;;
  release) release "$@" ;;
  *) die "unknown command $command" ;;
esac
