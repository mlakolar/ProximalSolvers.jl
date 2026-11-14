#!/bin/bash
# Paired measurement probes for one tree (master or the fix), run once per Julia version on the
# cluster (Slurm) through a helper that mirrors the tree and runs `julia <args>` in it.
# Usage: measure.sh <run-julia command prefix> <label>
#   <run-julia ...> must run `julia <args>` inside the tree with the right Julia version.
RUNJ=$1; LABEL=$2
$RUNJ --project=. probes/withenv.jl probes/counts313.jl $LABEL            # coordinate-visit counts, 392 runs (ROW lines)
$RUNJ --project=. probes/withenv.jl probes/alloc313.jl                    # bytes per pass and per solve
$RUNJ --project=. probes/withenv.jl probes/seeds313.jl 500 $LABEL         # #311 fixture seed scan
$RUNJ --project=. --code-coverage=user probes/withenv.jl probes/seeds313.jl 500 $LABEL   # same, coverage-instrumented
