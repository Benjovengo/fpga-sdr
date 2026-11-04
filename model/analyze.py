"""Filter analysis and figures for the README.

python -m model.analyze  ->  docs/figures/*.png and a summary of the latency/quality trade-off.
"""
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
import numpy as np  # noqa: E402
from scipy import signal  # noqa: E402

from . import design as d  # noqa: E402
from .ddc_model import ddc, step_stimulus  # noqa: E402

FIG_DIR = d.ROOT / "docs" / "figures"
N_FFT = 4096


def quantized(coef_set):
    return np.asarray(d.COEFS[coef_set], dtype=float) / 2 ** d.COEF_FRAC


def summary():
    """Passband ripple, stopband attenuation and DC group delay of each quantized filter."""
    f = np.linspace(0, 0.5, N_FFT)                      # cycles per output sample
    pas = f <= d.PASS_EDGE / 2
    stop = f >= d.STOP_EDGE / 2
    cic = d.cic_response(f)
    rows = []
    for name in d.COEFS:
        h = quantized(name)
        _, resp = signal.freqz(h, worN=2 * np.pi * f)
        total = np.abs(resp) * cic
        ripple = 20 * np.log10(total[pas].max() / total[pas].min())
        atten = -20 * np.log10(np.abs(resp[stop]).max() / np.abs(resp[0]))
        _, gd = signal.group_delay((h, [1.0]), w=2 * np.pi * f[pas])
        rows.append((name, ripple, atten, gd[0], gd.mean()))
    return rows


def plot_all():
    FIG_DIR.mkdir(parents=True, exist_ok=True)
    f = np.linspace(1e-6, 0.5, N_FFT)
    cic = d.cic_response(f)

    fig, ax = plt.subplots(figsize=(7, 4))
    ax.plot(f, 20 * np.log10(cic), label="CIC alone", color="0.6")
    for name in d.COEFS:
        _, resp = signal.freqz(quantized(name), worN=2 * np.pi * f)
        ax.plot(f, 20 * np.log10(np.abs(resp) * cic + 1e-12), label=f"CIC + FIR ({name})")
    ax.axvspan(0, d.PASS_EDGE / 2, alpha=0.08, label="passband")
    ax.set(xlabel="frequency (cycles per output sample)", ylabel="magnitude (dB)",
           ylim=(-90, 5), title="DDC magnitude response (quantized coefficients)")
    ax.grid(alpha=0.3)
    ax.legend()
    fig.tight_layout()
    fig.savefig(FIG_DIR / "magnitude.png", dpi=130)

    fig, ax = plt.subplots(figsize=(7, 4))
    fp = np.linspace(0, d.PASS_EDGE / 2, 400)
    for name in d.COEFS:
        _, gd = signal.group_delay((quantized(name), [1.0]), w=2 * np.pi * fp)
        ax.plot(fp, gd, label=name)
    ax.set(xlabel="frequency (cycles per output sample)", ylabel="group delay (output samples)",
           title="FIR group delay in the passband")
    ax.grid(alpha=0.3)
    ax.legend()
    fig.tight_layout()
    fig.savefig(FIG_DIR / "group_delay.png", dpi=130)

    fig, ax = plt.subplots(figsize=(7, 4))
    i, q, inc = step_stimulus()
    start = 64 // d.CIC_R
    for name in d.COEFS:
        out_i, _ = ddc(i, q, inc, name)
        ax.step(np.arange(len(out_i)) - start, out_i, where="post", label=name)
    ax.set(xlim=(-2, 30), xlabel="output samples after the input step", ylabel="output I",
           title="Step response (bit-accurate model)")
    ax.grid(alpha=0.3)
    ax.legend()
    fig.tight_layout()
    fig.savefig(FIG_DIR / "step_response.png", dpi=130)
    plt.close("all")


if __name__ == "__main__":
    plot_all()
    print(f"figures written to {FIG_DIR}")
    print(f"{'filter':<10} {'ripple dB':>10} {'stop atten dB':>14} {'GD at DC':>9} {'GD mean':>8}")
    for name, ripple, atten, gd0, gdm in summary():
        print(f"{name:<10} {ripple:10.2f} {atten:14.1f} {gd0:9.2f} {gdm:8.2f}")
