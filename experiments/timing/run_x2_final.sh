#!/bin/bash
set -u
RUN=<RUN>
T=$RUN/experiments/timing; cd <WORK>/ps-353
for spec in "lts:" "release:" "lts-alderlake:-C alderlake"; do
  tag=${spec%%:*}; flag=${spec#*:}; ch=${tag%%-*}
  uptime > $T/x2-final-$tag.load
  taskset -c 2 julia +$ch $flag --project=. $T/x2_paired.jl $T/x2-final-$tag.tsv 15 > $T/x2-final-$tag.log 2>&1
  uptime >> $T/x2-final-$tag.load
  python3 $T/summarize.py $T/x2-final-$tag.tsv > $T/x2-final-$tag.summary.txt 2>&1
done
echo done > $T/x2-final.done
