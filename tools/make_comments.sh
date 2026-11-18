#!/bin/bash
# Build the four issue comments from the report parts. Usage: make_comments.sh REV (e.g. r2)
set -euo pipefail
cd "$(dirname "$0")/../report"; REV=$1; P=post
hdr() { echo "**Stage 0 report for #353, revision $REV — part $1 of 4: $2**"; echo; }
{ hdr 1 "summary, decision memo, direct answers"; cat part-A.md; } > $P/comment-1.md
{ hdr 2 "ownership ledger (coordinate descent)"; cat part-B-head.md; echo; echo "### B1. Square-root lasso coordinate descent (\`src/cd/sqrtlasso.jl\`)"; echo; cat ledger-sqrt.md; echo; echo "### B2. Least-squares and group coordinate descent (\`src/cd/leastsquares.jl\`, \`models.jl\`, \`solver.jl\`)"; echo; cat ledger-ls.md; } > $P/comment-2.md
{ hdr 3 "ownership ledger (PGD, APG, ProximalBase)"; echo "Classes and conventions as in part 2."; echo; echo "### B3. PGD and APG (\`src/solvers/image_models.jl\`, \`blocks.jl\`, \`utils.jl\`, \`line_searches.jl\`, \`solve.jl\`, the two solver files)"; echo; cat ledger-pgd.md; echo; echo "### B4. ProximalBase side (pin \`a19c59aa\`)"; echo; cat ledger-pb.md; } > $P/comment-3.md
{ hdr 4 "recommendations, Do Not Change, ProximalBase interface, sequence, reproducibility"; echo "## C. Ranked recommendations"; echo; cat part-C-r1.md; echo; cat part-C-rest.md; echo; cat part-DE.md; echo; cat part-FG.md; } > $P/comment-4.md
wc -c $P/comment-*.md
