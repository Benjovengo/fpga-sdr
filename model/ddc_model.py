"""Bit-accurate model of the DDC and generator of the testbench vectors.

Every function reproduces the integer arithmetic of the matching RTL block (floor shifts,
two's-complement wrap-around, saturation), so the VHDL outputs must match it exactly.
The model is untimed: it gives the output *values*; latency in clock cycles is measured in RTL.
"""
from pathlib import Path

import numpy as np

from . import design as d


def wrap(v, width):
    """Two's-complement wrap-around, like numeric_std signed addition."""
    m = 1 << width
    v &= m - 1
    return v - m if v >= m >> 1 else v


def saturate(v, width):
    lim = 1 << (width - 1)
    return max(-lim, min(lim - 1, v))


def nco_mixer(i_in, q_in, phase_inc):
    """y = x * exp(-j*phase); phase advances by phase_inc per sample, starting at 0."""
    phase, mask = 0, (1 << d.PHASE_W) - 1
    out_i, out_q = [], []
    for i, q in zip(i_in, q_in):
        addr = phase >> (d.PHASE_W - d.LUT_AW)
        c, s = d.COS_LUT[addr], d.SIN_LUT[addr]
        out_i.append((i * c + q * s) >> d.MIX_SHIFT)
        out_q.append((q * c - i * s) >> d.MIX_SHIFT)
        phase = (phase + phase_inc) & mask
    return out_i, out_q


def cic_decimate(x):
    """N-stage CIC decimator, R:1, matching rtl/cic_decim.vhd register by register."""
    integ = [0] * d.CIC_N
    delay = [0] * d.CIC_N
    out, cnt = [], 0
    for v in x:
        if cnt == d.CIC_R - 1:          # the RTL captures the last integrator before it updates
            c = integ[-1]
            for k in range(d.CIC_N):
                c, delay[k] = wrap(c - delay[k], d.CIC_W), c
            out.append(c >> d.CIC_GROWTH)
        integ = [wrap(integ[0] + v, d.CIC_W)] + [
            wrap(integ[k] + integ[k - 1], d.CIC_W) for k in range(1, d.CIC_N)]
        cnt = (cnt + 1) % d.CIC_R
    return out


def fir(x, coefs):
    """y[n] = sum h[k] x[n-k], full precision, then floor-shift and saturate."""
    acc = np.convolve(np.asarray(x, dtype=np.int64), np.asarray(coefs, dtype=np.int64))[:len(x)]
    return [saturate(int(a) >> d.COEF_FRAC, d.OUT_W) for a in acc]


def ddc(i_in, q_in, phase_inc, coef_set):
    mi, mq = nco_mixer(i_in, q_in, phase_inc)
    coefs = d.COEFS[coef_set]
    return fir(cic_decimate(mi), coefs), fir(cic_decimate(mq), coefs)


# ------------------------------------------------------------------ stimuli
def phase_inc_for(freq):
    """NCO phase increment for a frequency in cycles per input sample (0 <= freq < 0.5)."""
    return int(round(freq * 2 ** d.PHASE_W))


def tone_stimulus(n=8192, seed=1):
    """Wanted signal 0.01*fs above the NCO, an out-of-band interferer and noise."""
    rng = np.random.default_rng(seed)
    t = np.arange(n)
    f_nco = 0.1
    x = (9000 * np.exp(2j * np.pi * (f_nco + 0.01) * t)
         + 6000 * np.exp(2j * np.pi * (f_nco + 0.11) * t)
         + rng.normal(0, 300, n) + 1j * rng.normal(0, 300, n))
    lim = 2 ** (d.IN_W - 1)
    i = np.clip(np.round(x.real), -lim, lim - 1).astype(int).tolist()
    q = np.clip(np.round(x.imag), -lim, lim - 1).astype(int).tolist()
    return i, q, phase_inc_for(f_nco)


def step_stimulus(zeros=64, ones=1024, amplitude=16384):
    """DC step on I with the NCO at 0 Hz: used to measure latency to 50 % of the final value."""
    i = [0] * zeros + [amplitude] * ones
    return i, [0] * len(i), 0


STIMULI = {"tone": tone_stimulus, "step": step_stimulus}


def write_vectors(out_dir):
    """<case>_in.txt: phase_inc, then 'i q' per input sample.
    <case>_<coefs>_out.txt: 'count final_i', then 'i q' per expected output sample."""
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    for case, make in STIMULI.items():
        i, q, inc = make()
        lines = [str(inc)] + [f"{a} {b}" for a, b in zip(i, q)]
        (out_dir / f"{case}_in.txt").write_text("\n".join(lines) + "\n")
        for coef_set in d.COEFS:
            oi, oq = ddc(i, q, inc, coef_set)
            lines = [f"{len(oi)} {oi[-1]}"] + [f"{a} {b}" for a, b in zip(oi, oq)]
            (out_dir / f"{case}_{coef_set}_out.txt").write_text("\n".join(lines) + "\n")
    return out_dir
