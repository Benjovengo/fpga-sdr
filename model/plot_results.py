"""Latency result plots for the README.

python -m model.plot_results  ->  doc/images/latency_by_config.png, latency_waterfall.png

Uses the latencies measured in RTL simulation (build/results/, written by run.py). Until the
RTL has been simulated it plots a cycle-exact *prediction* instead and says so in the titles:
the model gives the output sample that crosses 50 %, the pipeline register count gives the
cycles around it. Once both exist, the console shows predicted vs. measured.
"""
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402

from . import design as d  # noqa: E402
from .ddc_model import ddc, step_stimulus  # noqa: E402

RESULT_DIR = d.ROOT / "build" / "results"
FIG_DIR = d.ROOT / "doc" / "images"
F_CLK_MHZ = 245.76

CONFIGS = [  # (name, label, transposed, minphase); order = baseline first
    ("tree_linear", "Baseline\ntree + linear phase", False, False),
    ("tree_minphase", "tree + minimum phase", False, True),
    ("transposed_linear", "transposed + linear phase", True, False),
    ("transposed_minphase", "Low latency\ntransposed + minimum phase", True, True),
]

# Reference palette (validated: CVD dE 24.7, normal-vision dE 33.6, >= 3:1 on the surface)
SURFACE = "#fcfcfb"
TEXT = "#0b0b0b"
TEXT_2 = "#52514e"
GRID = "#e4e3df"
BLUE = "#2a78d6"     # slot 1
ORANGE = "#eb6834"   # slot 2

LEVELS = (d.FIR_TAPS - 1).bit_length()


def predicted(transposed, minphase):
    """(first response, 50 % of step) in cycles, from the model and the pipeline structure.

    Output sample m is captured by the CIC on the edge that processes mixer output m*R + R-1,
    which is 3 edges after that input (mixer pipeline). Then N comb edges + 1 output register,
    then the FIR: transposed = 1 edge, tree = x register + leaf products + LEVELS + output = LEVELS + 3.
    """
    i, q, inc = step_stimulus()
    step_at = i.index(next(v for v in i if v))
    out, _ = ddc(i, q, inc, "minphase" if minphase else "linear")
    fir_cycles = 1 if transposed else LEVELS + 3

    def edge(m):
        return m * d.CIC_R + d.CIC_R - 1 + 3 + d.CIC_N + 1 + fir_cycles - step_at

    first = next(m for m, v in enumerate(out) if v)
    half = next(m for m, v in enumerate(out) if 2 * abs(v) >= abs(out[-1]))
    return edge(first), edge(half)


def measured(name):
    f = RESULT_DIR / f"{name}_step.txt"
    if not f.exists():
        return None
    first, half, _ = (int(v) for v in f.read_text().split())
    return first, half


def style(ax):
    ax.set_facecolor(SURFACE)
    for side in ("top", "right", "left"):
        ax.spines[side].set_visible(False)
    ax.spines["bottom"].set_color(TEXT_2)
    ax.tick_params(colors=TEXT_2, length=0)
    ax.xaxis.grid(True, color=GRID, linewidth=0.8)
    ax.set_axisbelow(True)


def plot_by_config(rows, source):
    """Horizontal bars per configuration: 50 % step latency, with first response as a marker."""
    fig, ax = plt.subplots(figsize=(8, 3.8), facecolor=SURFACE)
    style(ax)
    ys = list(range(len(rows)))[::-1]
    base = rows[0][3]
    for y, (_, label, first, half) in zip(ys, rows):
        ax.barh(y, half, height=0.5, color=BLUE, edgecolor=SURFACE, linewidth=2)
        ax.plot(first, y, marker="D", markersize=8, color=ORANGE,
                markeredgecolor=SURFACE, markeredgewidth=2, linestyle="none")
        note = "" if half == base else f"  (-{100 * (base - half) / base:.0f} %)"
        ax.text(half + 3, y, f"{half} cycles = {half / F_CLK_MHZ * 1e3:.0f} ns{note}",
                va="center", color=TEXT, fontsize=9)
    ax.set_yticks(ys, [r[1] for r in rows], color=TEXT, fontsize=9)
    ax.set_xlim(0, max(r[3] for r in rows) * 1.45)
    ax.set_xlabel("clock cycles from input step (245.76 MHz input sample clock)", color=TEXT_2)
    ax.set_title(f"DDC latency by configuration ({source})", color=TEXT, loc="left", fontsize=11)
    ax.legend(handles=[
        plt.Rectangle((0, 0), 1, 1, color=BLUE, label="50 % of step reached"),
        plt.Line2D([], [], marker="D", color=ORANGE, linestyle="none", markersize=8,
                   label="first non-zero output")],
        loc="lower right", frameon=False, fontsize=9, labelcolor=TEXT)
    fig.tight_layout()
    fig.savefig(FIG_DIR / "latency_by_config.png", dpi=130, facecolor=SURFACE)
    plt.close(fig)


def plot_waterfall(by_name, source):
    """Baseline -> structural saving -> algorithmic saving -> low-latency result."""
    base = by_name["tree_linear"][1]
    after_struct = by_name["transposed_linear"][1]
    final = by_name["transposed_minphase"][1]
    steps = [
        ("Baseline\ntree + linear", 0, base, BLUE, f"{base}"),
        ("Transposed FIR\n(structural)", after_struct, base - after_struct, ORANGE, f"-{base - after_struct}"),
        ("Minimum-phase FIR\n(algorithmic)", final, after_struct - final, ORANGE, f"-{after_struct - final}"),
        ("Low latency\ntransposed + min phase", 0, final, BLUE, f"{final}"),
    ]
    fig, ax = plt.subplots(figsize=(8, 3.8), facecolor=SURFACE)
    style(ax)
    ax.xaxis.grid(False)
    ax.yaxis.grid(True, color=GRID, linewidth=0.8)
    for x, (label, bottom, height, color, text) in enumerate(steps):
        ax.bar(x, height, bottom=bottom, width=0.55, color=color, edgecolor=SURFACE, linewidth=2)
        ax.text(x, bottom + height + 3, text, ha="center", va="bottom", color=TEXT, fontsize=10)
    ax.set_xticks(range(len(steps)), [s[0] for s in steps], color=TEXT, fontsize=9)
    ax.set_ylim(0, base * 1.18)
    ax.set_ylabel("cycles to 50 % of step", color=TEXT_2)
    ax.set_title(f"Where the latency saving comes from ({source})", color=TEXT, loc="left", fontsize=11)
    ax.legend(handles=[plt.Rectangle((0, 0), 1, 1, color=BLUE, label="total latency"),
                       plt.Rectangle((0, 0), 1, 1, color=ORANGE, label="saving")],
              loc="upper right", frameon=False, fontsize=9, labelcolor=TEXT)
    fig.tight_layout()
    fig.savefig(FIG_DIR / "latency_waterfall.png", dpi=130, facecolor=SURFACE)
    plt.close(fig)


def main():
    FIG_DIR.mkdir(parents=True, exist_ok=True)
    pred = {n: predicted(t, m) for n, _, t, m in CONFIGS}
    meas = {n: measured(n) for n, *_ in CONFIGS}
    have_rtl = all(meas.values())
    values = meas if have_rtl else pred
    source = "measured in RTL simulation" if have_rtl else "PREDICTED - RTL not simulated yet"

    rows = [(n, label, *values[n]) for n, label, *_ in CONFIGS]
    plot_by_config(rows, source)
    plot_waterfall(values, source)

    print(f"figures written to {FIG_DIR} ({source})")
    print(f"{'configuration':<22} {'predicted first/50%':>20} {'measured first/50%':>20}")
    for n, *_ in CONFIGS:
        m = f"{meas[n][0]}/{meas[n][1]}" if meas[n] else "-"
        mark = "" if not meas[n] or meas[n] == pred[n] else "   <- differs"
        print(f"{n:<22} {pred[n][0]:>9}/{pred[n][1]:<10} {m:>20}{mark}")


if __name__ == "__main__":
    main()
