#!/bin/bash
# =====================================================================
# make_review_bundle.sh -- build a name-free ZIP of this repository for
# double-anonymized peer review.
#
#   bash make_review_bundle.sh            -> review-bundle.zip (current directory)
#   bash make_review_bundle.sh out.zip    -> out.zip (its directory must exist)
#
# The named repository is the artifact of record and is what the arXiv version
# links to. This script produces a SEPARATE, anonymized copy for journal
# submission. It never modifies the working tree. Requires git, tar, zip,
# unzip, perl, GNU sed and pdfinfo (poppler); it stops if any is missing.
#
# WHAT IT DOES
#   1. Exports the tracked tree at HEAD with `git archive`, so .git/ -- which
#      carries the author name in every commit, plus the remote URL -- is never
#      in the bundle. Untracked files are excluded for the same reason.
#      It then ABORTS if any benchmark data or unit-level file (data/, .dta,
#      .csv, .sav, .rda/.RData, lalonde_overlap*.rds, rhc_analysis*.rds; all
#      matched case-insensitively), any .rds (any case) not on the reviewed
#      allowlist, or any symbolic link or other non-regular file would ship.
#   2. Replaces CITATION.cff with an anonymous stub (no name, no ORCID), and
#      removes .zenodo.json, the named release's archive metadata, and this
#      script itself.
#   3. Replaces the licence copyright line with "the Author(s)".
#   4. Rewrites the README for the bundle: its "Anonymized bundle for peer
#      review" section becomes one line and the .zenodo.json/archive sentence
#      is dropped; every remaining mention of this script becomes "the
#      review-bundle build".
#   5. Rewrites institution- and project-identifying strings: "ARC", which names
#      a specific university's computing platform, becomes neutral cluster
#      wording, and "TMLE-variants", the stem of the named repository's public
#      name, becomes neutral wording.
#   6. Neutralizes site-specific cluster settings: the allocation placeholder
#      def-YOURACCOUNT (a site's allocation naming scheme) becomes
#      YOUR_ALLOCATION, and the site's `module load` lines become
#      `module load YOUR_R_MODULE`.
#   7. Drops the private build SHA from R/BUILD_INFO.txt, which resolves only in
#      the authors' own source repository, and withholds the same SHA in every
#      other text file that quotes it (R/15_record_environment.R).
#   8. Withholds this repository's own commit hashes: every 7-40 hex-digit token
#      in a staged text file that is a prefix of a commit in
#      `git rev-list --all --reflog` becomes "(withheld for review)".
#   9. Verifies, and ABORTS on any failure: every staged file has a reviewed
#      extension (or is one of the reviewed extension-less files); no identity
#      pattern survives (names, ORCID, e-mail, GitHub, institution, local paths
#      and accounts); the build SHA is gone; no hex token still resolves to a
#      commit; ".zenodo.json" and "make_review_bundle" appear in no staged text;
#      no site-specific allocation or module line remains; every staged PDF's
#      creation and modification dates carry no local UTC offset; the
#      third-party credit survives (THIRD_PARTY_NOTICES.md, the R/dgm.R
#      attribution header, the CITATION.cff reference), since the CC BY 4.0
#      upstream material must keep its attribution in the bundle.
#  10. Zips with one fixed timestamp for every entry, no extra fields (no build
#      time, time zone or local UID/GID) and no comment, then re-reads the ZIP's
#      central directory and ABORTS unless every entry has a zero-length extra
#      field and the fixed timestamp, and there is no comment.
#
# WHAT IT DELIBERATELY DOES NOT DO
#   The benchmark data are not in the repository, so there is nothing to strip
#   there. The simulation results (output/compass_maps.rds, compass_report.txt)
#   are binary/text results with no author metadata and are shipped unchanged --
#   they are the evidence a reviewer needs. So are the saved applied-analysis
#   results (output/rhc_factorial_{fast,rf}.rds, rhc_overlap_diag.rds,
#   lalonde_estimates.rds; see output/APPLIED_PROVENANCE.md). They hold summary
#   results, including the minimum and maximum fitted propensities (overall and
#   by arm) in rhc_overlap_diag.rds.
#   Binary files (.rds, .pdf) are not rewritten; the identity scan still reads them.
# =====================================================================
set -euo pipefail

OUT="${1:-review-bundle.zip}"
OUT_DIR="$(dirname "$OUT")"
if [ ! -d "$OUT_DIR" ]; then
  echo "ABORTING -- the output directory '$OUT_DIR' does not exist; create it first or pass a" >&2
  echo "            path in an existing directory (e.g. bash make_review_bundle.sh /tmp/review-bundle.zip)" >&2
  exit 1
fi
OUT="$(cd "$OUT_DIR" && pwd)/$(basename "$OUT")"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

for tool in git tar zip unzip perl sed pdfinfo; do
  command -v "$tool" >/dev/null || { echo "ABORTING -- '$tool' not found; it is required to build and verify the bundle" >&2; exit 1; }
done
sed --version 2>/dev/null | grep -q 'GNU sed' || { echo "ABORTING -- GNU sed is required (word boundaries, the I flag)" >&2; exit 1; }

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

# Staged text files, NUL-separated: the reviewed text extensions plus the reviewed
# extension-less files. The binary types (.rds, .pdf) are never rewritten.
TEXT_EXT_RE='\.(R|sh|slurm|md|txt|cff)$'
NOEXT_RE='^\./(LICENSE|\.gitattributes|\.gitignore)$'
text_files() {
  ( cd "$STAGE" && find . -type f -print0 ) |
    while IFS= read -r -d '' p; do
      if [[ "$p" =~ $TEXT_EXT_RE || "$p" =~ $NOEXT_RE ]]; then printf '%s\0' "$STAGE/${p#./}"; fi
    done
}
# grep over all staged text files in ONE call, so its exit status keeps grep's
# meaning (0 match, 1 none, >=2 error), which xargs would blur.
grep_text() {
  local files=() f
  while IFS= read -r -d '' f; do files+=("$f"); done < <(text_files)
  [ "${#files[@]}" -gt 0 ] || return 1
  grep "$@" -- "${files[@]}"
}
# Hex tokens of 7-40 digits in the staged text, lower-cased, one per line.
hex_tokens() {
  { grep_text -ohE '\b[0-9A-Fa-f]{7,40}\b' || true; } | tr 'A-F' 'a-f' | LC_ALL=C sort -u
}
# Tokens (stdin) that are a prefix of a commit in $COMMITS.
commit_prefixes() {
  awk 'NR == FNR { c[NR] = $0; n = NR; next }
       $0 != "" { for (i = 1; i <= n; i++) if (index(c[i], $0) == 1) { print $0; break } }' \
    <(printf '%s\n' "$COMMITS") -
}

echo "==> exporting tracked tree at HEAD (no .git, no untracked files)"
git archive --format=tar HEAD | tar -x -C "$STAGE"
echo "==> verifying no benchmark data or unit-level files are staged"
DATA_HITS="$(cd "$STAGE" && find . \( -ipath './data/*' -o -iname '*.dta' -o -iname '*.csv' \
  -o -iname '*.sav' -o -iname '*.rda' -o -iname '*.rdata' -o -iname 'lalonde_overlap*.rds' \
  -o -iname 'rhc_analysis*.rds' \) -print)"
if [ -n "$DATA_HITS" ]; then
  echo "ABORTING -- benchmark data or unit-level files would ship:" >&2; echo "$DATA_HITS" >&2; exit 1
fi
# Any new saved input must be reviewed and added here deliberately. The four applied-analysis
# files were reviewed for unit-level content (see output/APPLIED_PROVENANCE.md, Unit-level
# content): no unit-level data and no per-unit vector. rhc_factorial_{fast,rf}.rds hold per-arm
# estimates; rhc_overlap_diag.rds holds counts, quantiles, shares and the minimum and
# maximum fitted propensities (overall and by arm), all summary statistics;
# lalonde_estimates.rds holds the aggregate LaLonde results without the per-unit $ps of
# lalonde_overlap.rds, which stays blocked above. The extension is matched in any case and
# the allowlist exactly, so OUTPUT/X.RDS or a renamed copy cannot slip through.
ALLOWED_RDS='^\./(output/(compass_maps|s4_repetition_input|s5_diagnostics_input|truths|rhc_factorial_fast|rhc_factorial_rf|rhc_overlap_diag|lalonde_estimates)\.rds|R/truths\.rds)$'
EXTRA_RDS="$(cd "$STAGE" && find . -iname '*.rds' | grep -Ev "$ALLOWED_RDS" || true)"
if [ -n "$EXTRA_RDS" ]; then
  echo "ABORTING -- .rds not on the reviewed allowlist would ship:" >&2; echo "$EXTRA_RDS" >&2; exit 1
fi
ODD="$(cd "$STAGE" && find . ! -type f ! -type d -print)"
if [ -n "$ODD" ]; then
  echo "ABORTING -- symbolic links or other non-regular files would ship:" >&2; echo "$ODD" >&2; exit 1
fi

echo "==> stubbing CITATION.cff"
cat > "$STAGE/CITATION.cff" <<'CFF'
cff-version: 1.2.0
message: "Author and citation metadata are withheld for double-anonymized peer review."
title: "When Sample-Splitting Choices Matter in TMLE and AIPW: Cross-Fitting, Targeting, and Repetition"
authors:
  - name: "Author(s) withheld for peer review"
year: 2026
references:
  - type: software
    title: "pzivich/publications-code"
    version: "v2026.07.20"
    authors:
      - family-names: Zivich
        given-names: Paul
    doi: "10.5281/zenodo.21456065"
    license: CC-BY-4.0
    notes: "R/dgm.R adapts DoubleCrossFit/Python/dgm.py from this release; see THIRD_PARTY_NOTICES.md."
CFF

echo "==> anonymizing the licence copyright line"
sed -i'' -e 's/^Copyright (c) [0-9]\{4\}.*$/Copyright (c) 2026 the Author(s)/' "$STAGE/LICENSE"

echo "==> removing this script and the named release metadata from the bundle"
rm -f "$STAGE/make_review_bundle.sh"
# .zenodo.json names the creator (with ORCID) for the named repository's archived
# release; the anonymized copy has no release of its own.
rm -f "$STAGE/.zenodo.json"

echo "==> rewriting the README for the bundle"
# The section that describes this script becomes one line, and the sentence that
# points to .zenodo.json and the archive release is dropped. Both are verified
# below (no ".zenodo.json" and no "make_review_bundle" may remain).
perl -0pi -e 's/(## Anonymized bundle for peer review\n\n).*?(?=\n## )/${1}This copy is the anonymized bundle prepared for double-anonymized peer review; author, institution and repository identifiers are withheld.\n/s' "$STAGE/README.md"
perl -0pi -e "s/ Archive metadata for the repository's\\s+Zenodo release:.*?No deposit has been made yet\\.//s" "$STAGE/README.md"
# Other mentions of this script (README Data section, APPLIED_PROVENANCE.md, R/06).
text_files | xargs -0 -r sed -i'' -e 's/`make_review_bundle\.sh`/the review-bundle build/g' \
                                -e 's/make_review_bundle\.sh/the review-bundle build/g'

echo "==> removing institution- and project-identifying strings"
# "ARC" is a named university computing platform; neutralise it everywhere.
# "TMLE-variants" is the stem of the named repository's public name, so a search
# for it would lead straight to the authors; neutralise it too.
text_files | xargs -0 -r sed -i'' \
    -e 's/TMLE-variants tutorial/tutorial/g' \
    -e 's/TMLE-variants-code/the companion repository/g' \
    -e 's/TMLE-variants/the project/g' \
    -e 's/the ARC 6h template/the site 6h walltime template/g' \
    -e 's/COMPASS ARC bundle build/COMPASS engine build/g' \
    -e 's/COMPASS ARC worker/COMPASS cluster worker/g' \
    -e 's/bundle root on ARC/bundle root on the cluster/g' \
    -e 's/the ARC package/the cluster package/g' \
    -e 's/ARC output/cluster output/g' \
    -e 's/\bon ARC\b/on the cluster/g' \
    `# catch-all, after the specific phrases above: a new ARC mention in any` \
    `# other wording must not reach the guard unhandled.` \
    -e 's/compass-ARC-upload/compass-cluster-bundle/g' \
    -e 's/\bARC\b/the cluster/g'

echo "==> neutralizing site-specific cluster settings"
# def-<name> is one site's allocation naming scheme, and the module names (gcc/9.4.0,
# r/4.4.0) are that site's software stack. A standalone compiler-module line is
# dropped; every other module load becomes the placeholder YOUR_R_MODULE.
text_files | xargs -0 -r sed -i'' \
    -e 's/def-YOURACCOUNT/YOUR_ALLOCATION/g' \
    -e '/^[[:space:]]*module load gcc\/[^[:space:]]*[[:space:]]*$/d' \
    -e 's/module load \([A-Za-z0-9_.+-]*\/[A-Za-z0-9_.+-]*[[:space:]]*\)\{1,\}/module load YOUR_R_MODULE /g' \
    -e 's/module load YOUR_R_MODULE \([;"]\)/module load YOUR_R_MODULE\1/g' \
    -e 's/module load YOUR_R_MODULE $/module load YOUR_R_MODULE/'

echo "==> dropping the private build SHA"
BUILD_SHA=""
if [ -f "$STAGE/R/BUILD_INFO.txt" ]; then
  BUILD_SHA="$(head -n 1 "$STAGE/R/BUILD_INFO.txt" | tr -d '[:space:]')"
  case "$BUILD_SHA" in
    ""|*[!0-9a-f]*)
      echo "ABORTING -- R/BUILD_INFO.txt does not start with a hex build SHA ('$BUILD_SHA')" >&2; exit 1 ;;
  esac
  {
    echo "COMPASS engine build -- frozen for the simulation run reported in the paper."
    echo "Build identifiers from the authors' private source repository are withheld"
    echo "for double-anonymized review."
  } > "$STAGE/R/BUILD_INFO.txt"
  # The same SHA is quoted elsewhere (R/15_record_environment.R writes it into
  # ENVIRONMENT.md); withhold it in every text file. Verified after the identity scan.
  { grep_text -lF "$BUILD_SHA" || true; } | while IFS= read -r f; do
    sed -i'' -e "s/$BUILD_SHA/(withheld for review)/g" "$f"
  done
fi

echo "==> withholding this repository's own commit hashes"
# Every commit any ref or reflog of this repository knows, including the public
# remote's: a quoted prefix of any of them would lead to the named repository.
COMMITS="$(git rev-list --all --reflog)"
[ -n "$COMMITS" ] || { echo "ABORTING -- git rev-list returned no commits" >&2; exit 1; }
WITHHELD=0
while IFS= read -r t; do
  [ -n "$t" ] || continue
  { grep_text -liE "\\b$t\\b" || true; } | while IFS= read -r f; do
    sed -i'' -E "s/\\b$t\\b/(withheld for review)/gI" "$f"
    echo "    withheld a commit hash in ${f#"$STAGE"/}"
  done
  WITHHELD=$((WITHHELD + 1))
done < <(hex_tokens | commit_prefixes)
echo "    $WITHHELD distinct commit-hash token(s) withheld"

echo "==> verifying every staged file has a reviewed extension"
BAD_EXT="$(cd "$STAGE" && find . -type f | LC_ALL=C sort |
  grep -Ev "$NOEXT_RE" | grep -Ev '\.(R|sh|slurm|md|txt|cff|rds|pdf)$' || true)"
if [ -n "$BAD_EXT" ]; then
  echo "ABORTING -- files with an unreviewed extension would ship (review them, then extend the list):" >&2
  echo "$BAD_EXT" >&2; exit 1
fi
echo "    all extensions reviewed (.R .sh .slurm .md .txt .cff .rds .pdf; LICENSE, .gitattributes, .gitignore)"

echo "==> verifying no identity survives"
PATTERNS='karim|ehsan|ehsanx|mekarim|orcid|0000-0002-0346-2871|british columbia|\bUBC\b|\bARC\b|@[A-Za-z0-9.-]+\.(com|ca|org|edu)|github\.com|tmle-variants|wilds|[A-Za-z]:[/\\](Users|GitHub)|/c/Users|/e/GitHub|AppData|scratchpad'
# grep exits 0 = matches, 1 = no matches, >=2 = ERROR. Treating >=2 as "clean"
# would let a scan failure ship a named bundle, so each case is handled
# explicitly and stderr is captured rather than discarded. The error file lives
# outside the staging tree so it is never zipped. The scan reads every file,
# binary ones included, case-insensitively.
GERR="$(mktemp)"
set +e
HITS="$(grep -rinE "$PATTERNS" "$STAGE" 2>"$GERR")"
RC=$?
set -e
ERRTXT="$(cat "$GERR")"; rm -f "$GERR"
case "$RC" in
  0)
    echo "ABORTING -- identity patterns survived the rewrite:" >&2
    echo "$HITS" >&2
    exit 1
    ;;
  1)
    if [ -n "$ERRTXT" ]; then
      echo "ABORTING -- the identity scan reported errors, so 'no matches' cannot be trusted:" >&2
      echo "$ERRTXT" >&2
      exit 1
    fi
    echo "    clean (scan completed, no matches)"
    ;;
  *)
    echo "ABORTING -- the identity scan FAILED (grep exit $RC); the bundle was NOT verified:" >&2
    echo "$ERRTXT" >&2
    exit 1
    ;;
esac
if [ -n "$BUILD_SHA" ]; then
  set +e
  SHA_HITS="$(grep -rnIF "$BUILD_SHA" "$STAGE" 2>&1)"
  SRC=$?
  set -e
  if [ "$SRC" -ne 1 ]; then
    echo "ABORTING -- the private build SHA survives, or the scan failed (grep exit $SRC):" >&2
    echo "$SHA_HITS" >&2
    exit 1
  fi
  echo "    private build SHA absent"
fi

echo "==> verifying no staged token resolves to a commit of this repository"
TOKENS="$(hex_tokens)"
LEFT="$(printf '%s\n' "$TOKENS" | commit_prefixes)"
RESOLVED="$(printf '%s\n' "$TOKENS" | sed -e '/^$/d' -e 's/$/^{commit}/' |
  git cat-file --batch-check | awk '$2 == "commit" { print $1 }')"
if [ -n "$LEFT" ] || [ -n "$RESOLVED" ]; then
  echo "ABORTING -- staged text still names commits of this repository:" >&2
  printf '%s\n' "$LEFT" "$RESOLVED" | sed '/^$/d' >&2
  exit 1
fi
echo "    none ($(printf '%s\n' "$TOKENS" | sed '/^$/d' | wc -l | tr -d ' ') hex tokens checked)"

echo "==> verifying the release metadata and this script are not referenced"
set +e
REF_HITS="$(grep_text -nF -e '.zenodo.json' -e 'make_review_bundle' 2>&1)"
RRC=$?
set -e
if [ "$RRC" -ne 1 ]; then
  echo "ABORTING -- '.zenodo.json' or 'make_review_bundle' survives, or the scan failed (grep exit $RRC):" >&2
  echo "$REF_HITS" >&2
  exit 1
fi
echo "    neither is referenced"

echo "==> verifying no site-specific cluster setting survives"
set +e
SITE_HITS="$(grep_text -niE -e '\bdef-[a-z0-9_]+' -e 'module load +([^Y;" ]|Y[^O])' 2>&1)"
SRC2=$?
set -e
if [ "$SRC2" -ne 1 ]; then
  echo "ABORTING -- a site-specific allocation or module line survives, or the scan failed (grep exit $SRC2):" >&2
  echo "$SITE_HITS" >&2
  exit 1
fi
echo "    allocation and module lines are placeholders"

echo "==> verifying the PDFs carry no local time zone"
# cairo_pdf stamps local time with its UTC offset (D:...-07'00); an offset would
# reveal where the figures were drawn. pdfinfo -isodates prints Z for UTC.
TZ_BAD=""
while IFS= read -r -d '' pdf; do
  INFO="$(pdfinfo -isodates "$pdf" 2>/dev/null)" || { TZ_BAD+="${pdf#"$STAGE"/}: pdfinfo failed"$'\n'; continue; }
  BAD_DATES="$(printf '%s\n' "$INFO" | grep -E '^(CreationDate|ModDate):' | grep -vE 'Z$' || true)"
  [ -z "$BAD_DATES" ] || TZ_BAD+="${pdf#"$STAGE"/}: $BAD_DATES"$'\n'
done < <(find "$STAGE" -type f -iname '*.pdf' -print0)
if [ -n "$TZ_BAD" ]; then
  echo "ABORTING -- PDF dates carry a local UTC offset (redraw with TZ=UTC in the environment):" >&2
  printf '%s' "$TZ_BAD" >&2
  exit 1
fi
echo "    PDF dates are UTC"

echo "==> verifying third-party credit survives"
for need in "THIRD_PARTY_NOTICES.md:Zivich" "THIRD_PARTY_NOTICES.md:CC BY 4.0" \
            "THIRD_PARTY_NOTICES.md:10.5281/zenodo.21456065" "R/dgm.R:CC BY 4.0" \
            "R/dgm.R:10.5281/zenodo.21456065" "CITATION.cff:10.5281/zenodo.21456065"; do
  f="${need%%:*}"; s="${need#*:}"
  if [ ! -f "$STAGE/$f" ] || ! grep -qF "$s" "$STAGE/$f"; then
    echo "ABORTING -- third-party credit missing: '$s' not found in $f" >&2
    exit 1
  fi
done
echo "    third-party credit present"

echo "==> zipping (fixed timestamps, no extra fields, no comment)"
rm -f "$OUT"
# Every entry gets one fixed modification time, and -X drops the extra fields:
# the Unix UID/GID of the build account, and UTC timestamps, which next to the
# local DOS time would reveal the builder's time zone. The archive then carries
# no build-machine trace, and the same tree always gives the same ZIP.
FIXED_DOS='2026 Jan 1 00:00:00'
find "$STAGE" -exec env TZ=UTC touch -h -d '2026-01-01 00:00:00' {} +
( cd "$STAGE" && TZ=UTC zip -qrX "$OUT" . -x '.git/*' )
# Re-read the central directory: the entry count must equal the number of entries
# with a zero-length extra field AND the number with the fixed DOS timestamp.
ZMETA="$(unzip -Z -v "$OUT")"
N_ENTRIES="$(unzip -Z -1 "$OUT" | wc -l | tr -d ' ')"
N_NOEXTRA="$(printf '%s\n' "$ZMETA" | grep -cE '^[[:space:]]*length of extra field:[[:space:]]+0 bytes$' || true)"
N_EXTRA_LINES="$(printf '%s\n' "$ZMETA" | grep -cE '^[[:space:]]*length of extra field:' || true)"
N_FIXED="$(printf '%s\n' "$ZMETA" | grep -cE "^[[:space:]]*file last modified on \(DOS date/time\):[[:space:]]+$FIXED_DOS$" || true)"
N_TIME_LINES="$(printf '%s\n' "$ZMETA" | grep -cE '^[[:space:]]*file last modified on' || true)"
ZFAIL=""
[ "$N_ENTRIES" -gt 0 ] || ZFAIL+="no entries; "
[ "$N_EXTRA_LINES" = "$N_ENTRIES" ] && [ "$N_NOEXTRA" = "$N_ENTRIES" ] ||
  ZFAIL+="extra fields: $N_NOEXTRA of $N_ENTRIES entries have length 0 ($N_EXTRA_LINES reported); "
[ "$N_TIME_LINES" = "$N_ENTRIES" ] && [ "$N_FIXED" = "$N_ENTRIES" ] ||
  ZFAIL+="timestamps: $N_FIXED of $N_ENTRIES entries at $FIXED_DOS ($N_TIME_LINES timestamps reported); "
if printf '%s\n' "$ZMETA" | grep -qE '0x5455|0x5855|0x7875|0x000a|zipfile comment is'; then
  ZFAIL+="extra-field IDs or a comment present: $(printf '%s\n' "$ZMETA" | grep -oE '0x5455|0x5855|0x7875|0x000a|zipfile comment is' | sort -u | tr '\n' ' ')"
fi
if [ -n "$ZFAIL" ]; then
  echo "ABORTING -- the ZIP metadata check failed: $ZFAIL" >&2
  rm -f "$OUT"; exit 1
fi
echo "    ZIP metadata clean: $N_ENTRIES entries, every one with a zero-length extra field and"
echo "    the fixed timestamp ($FIXED_DOS); no comment"
echo
echo "Wrote $OUT"
echo "Contents: $(cd "$STAGE" && find . -type f | wc -l | tr -d ' ') files ($N_ENTRIES ZIP entries, directories included)"
echo
echo "Before uploading, confirm the paper itself is anonymized too: the bundle"
echo "cannot remove author names from the manuscript PDF."
