"""Render the lecture's scientific figures from retained solver output.

Optional tooling only: python -m pip install matplotlib numpy
"""
import argparse
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.colors import TwoSlopeNorm
import numpy as np

parser = argparse.ArgumentParser()
parser.add_argument("--data", type=Path, default=Path(__file__).parent / "measurements-20261025")
parser.add_argument("--preview", type=Path, default=Path(__file__).parent / "results")
args = parser.parse_args()
assets = Path(__file__).resolve().parents[2] / "docs" / "src" / "assets"
assets.mkdir(parents=True, exist_ok=True)
args.preview.mkdir(parents=True, exist_ok=True)
plt.rcParams.update({"font.size": 10, "axes.spines.top": False, "axes.spines.right": False,
                     "svg.fonttype": "none", "svg.hashsalt": "composite-lessons"})

graph = np.genfromtxt(args.data / "graph-256-fits.csv", delimiter=",", names=True)
fig, axes = plt.subplots(1, 2, figsize=(7.6, 3.6), layout="constrained")
norm = TwoSlopeNorm(vmin=-1.1, vcenter=0, vmax=2.1)
for ax, field, title in zip(axes, ("truth", "fit"), ("Planted coefficients", "Graph-fused regression fit")):
    im = ax.imshow(graph[field].reshape((16, 16), order="F"), origin="lower", cmap="RdBu_r", norm=norm)
    ax.set(title=title, xlabel="Grid column", ylabel="Grid row", xticks=[0, 5, 10, 15], yticks=[0, 5, 10, 15])
fig.colorbar(im, ax=axes, shrink=0.85, label="Coefficient")
fig.savefig(assets / "composite-graph.svg", metadata={"Date": None})
fig.savefig(args.preview / "composite-graph.png", dpi=160)
plt.close(fig)

trend = np.genfromtxt(args.data / "trend-400-fits.csv", delimiter=",", names=True)
fig, axes = plt.subplots(1, 2, figsize=(9.2, 3.5), layout="constrained")
t = np.linspace(0, 1, len(trend))
axes[0].scatter(t, trend["observation"], s=7, color="0.7", alpha=0.65, label="Observations", rasterized=True)
axes[0].plot(t, trend["truth"], color="#245b83", linewidth=1.8, linestyle="--", label="Planted signal")
axes[0].plot(t, trend["fit"], color="#b44d26", linewidth=1.6, label="Trend-filtering fit")
axes[0].set(title="Statistical fit", xlabel="Position", ylabel="Signal")
axes[0].legend(fontsize=8, frameon=False)
axes[1].plot(t, trend["fit"] - trend["reference"], color="#b44d26", linewidth=1.1)
axes[1].axhline(0, color="0.6", linewidth=0.7)
axes[1].set(title="Optimization discrepancy", xlabel="Position", ylabel="Condat–Vũ minus QP reference")
axes[1].ticklabel_format(axis="y", style="sci", scilimits=(0, 0))
fig.savefig(assets / "composite-trend.svg", metadata={"Date": None})
fig.savefig(args.preview / "composite-trend.png", dpi=160)
plt.close(fig)

# Matplotlib leaves spaces at SVG path line endings; keep generated sources
# clean without changing the whitespace separating SVG coordinates.
for name in ("composite-graph.svg", "composite-trend.svg"):
    path = assets / name
    path.write_text("\n".join(line.rstrip() for line in path.read_text().splitlines()) + "\n")
