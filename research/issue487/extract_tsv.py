"""Copy the tab-separated result rows (header + rows) out of a battery log, dropping the log's own lines."""
import sys
src, dst, first = sys.argv[1], sys.argv[2], sys.argv[3]
hdr = None; out = []
for line in open(src, encoding="utf-8"):
    line = line.rstrip("\n")
    if line.startswith(first + "\t"):
        hdr = line; continue
    if hdr and line.count("\t") == hdr.count("\t"):
        out.append(line)
with open(dst, "w", encoding="utf-8") as f:
    f.write(hdr + "\n"); f.write("\n".join(out) + "\n")
print(dst, len(out))
