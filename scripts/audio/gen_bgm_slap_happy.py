"""
常态 BGM「Slap Happy」程序化作曲 + 合成（原创，无外部采样）。

- 128 BPM，C 大调，32 小节 = 60 秒，首尾无缝循环（尾音回卷到开头）
- 结构：A(8) B(8) A'(8, 加琶音) B'(8, 加三度和声)
- 音色：脉冲波主旋律 / 反拍锯齿和弦（类铜管 stab）/ 方波贝斯 / 合成鼓 + 拍手
- 输出 assets/audio/BGM_SlapHappy.wav（44.1kHz 16bit 立体声）

用法：python scripts/audio/gen_bgm_slap_happy.py
"""

from pathlib import Path

import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, sosfilt

SR = 44100
BPM = 128
BEAT = 60.0 / BPM
EIGHTH = BEAT / 2
STEP16 = BEAT / 4
BARS = 32
BAR_SEC = BEAT * 4
TOTAL_N = int(round(BARS * BAR_SEC * SR))
TAIL_N = int(2.5 * SR)

OUT_PATH = Path(__file__).resolve().parents[2] / "assets" / "audio" / "BGM_SlapHappy.wav"

rng = np.random.default_rng(20261016)

NOTE_PC = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
C_MAJOR = [0, 2, 4, 5, 7, 9, 11]


def note_to_midi(name: str) -> int:
    pc = NOTE_PC[name[0]]
    rest = name[1:]
    if rest.startswith("#"):
        pc += 1
        rest = rest[1:]
    elif rest.startswith("b"):
        pc -= 1
        rest = rest[1:]
    return 12 * (int(rest) + 1) + pc


def midi_to_freq(m: float) -> float:
    return 440.0 * 2 ** ((m - 69) / 12)


def diatonic_shift(midi: int, degrees: int) -> int:
    octave, pc = divmod(midi, 12)
    idx = C_MAJOR.index(pc)
    idx += degrees
    o2, idx = divmod(idx, 7)
    return (octave + o2) * 12 + C_MAJOR[idx]


# ---------------- 振荡器 ----------------

def _polyblep(t, dt):
    y = np.zeros_like(t)
    m = t < dt
    x = t[m] / dt[m]
    y[m] = x + x - x * x - 1.0
    m = t > 1.0 - dt
    x = (t[m] - 1.0) / dt[m]
    y[m] = x * x + x + x + 1.0
    return y


def _phase(freq_arr):
    dt = freq_arr / SR
    return np.cumsum(dt) % 1.0, dt


def osc_saw(freq_arr):
    t, dt = _phase(freq_arr)
    return 2.0 * t - 1.0 - _polyblep(t, dt)


def osc_pulse(freq_arr, duty=0.5):
    t, dt = _phase(freq_arr)
    y = np.where(t < duty, 1.0, -1.0)
    y += _polyblep(t, dt)
    y -= _polyblep((t + 1.0 - duty) % 1.0, dt)
    return y - (2 * duty - 1)


def osc_tri(freq_arr):
    t, _ = _phase(freq_arr)
    return 4.0 * np.abs(t - 0.5) - 1.0


def adsr(n, gate_n, a, d, s, r):
    env = np.zeros(n)
    an, dn, rn = max(1, int(a * SR)), max(1, int(d * SR)), max(1, int(r * SR))
    gate_n = min(gate_n, n)
    idx = np.arange(gate_n)
    seg = np.where(
        idx < an,
        idx / an,
        np.where(idx < an + dn, 1.0 - (1.0 - s) * (idx - an) / dn, s),
    )
    env[:gate_n] = seg
    last = seg[-1] if gate_n > 0 else 0.0
    rel_len = min(rn, n - gate_n)
    if rel_len > 0:
        env[gate_n:gate_n + rel_len] = last * (1.0 - np.arange(rel_len) / rn)
    return env


def lowpass(x, cutoff, order=2):
    return sosfilt(butter(order, cutoff, "low", fs=SR, output="sos"), x)


def highpass(x, cutoff, order=2):
    return sosfilt(butter(order, cutoff, "high", fs=SR, output="sos"), x)


def bandpass(x, lo, hi, order=2):
    return sosfilt(butter(order, [lo, hi], "band", fs=SR, output="sos"), x)


# ---------------- 乐器 ----------------

def inst_lead(midi, dur):
    gate = int(dur * 0.85 * SR)
    n = gate + int(0.12 * SR)
    t = np.arange(n) / SR
    vib_depth = np.clip((t - 0.12) / 0.15, 0, 1) * 0.15
    m = midi + vib_depth * np.sin(2 * np.pi * 5.5 * t)
    f = 440.0 * 2 ** ((m - 69) / 12)
    y = 0.6 * osc_pulse(f, 0.25) + 0.4 * osc_saw(f * 2 ** (7 / 1200))
    y = lowpass(y, 4500)
    return y * adsr(n, gate, 0.006, 0.12, 0.6, 0.08)


def inst_stab(midis, dur=0.13):
    n = int((dur + 0.06) * SR)
    y = np.zeros(n)
    for m in midis:
        f = np.full(n, midi_to_freq(m))
        y += osc_saw(f) + 0.5 * osc_saw(f * 2 ** (-8 / 1200))
    y = lowpass(y, 2600)
    return y * adsr(n, int(dur * SR), 0.008, 0.09, 0.25, 0.05) / len(midis)


def inst_bass(midi, dur):
    gate = int(dur * 0.8 * SR)
    n = gate + int(0.04 * SR)
    f = np.full(n, midi_to_freq(midi))
    t = np.arange(n) / SR
    y = 0.7 * lowpass(osc_pulse(f, 0.5), 800) + 0.5 * np.sin(2 * np.pi * f * t)
    return y * adsr(n, gate, 0.003, 0.15, 0.55, 0.03)


def inst_arp(midi, dur):
    gate = int(dur * 0.7 * SR)
    n = gate + int(0.05 * SR)
    y = osc_tri(np.full(n, midi_to_freq(midi)))
    return y * adsr(n, gate, 0.002, 0.08, 0.3, 0.04)


def drum_kick():
    n = int(0.35 * SR)
    t = np.arange(n) / SR
    f = 45 + 110 * np.exp(-t / 0.03)
    y = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.18)
    click = rng.standard_normal(n) * np.exp(-t / 0.002) * 0.3
    return np.tanh(1.6 * (y + click))


def drum_snare():
    n = int(0.25 * SR)
    t = np.arange(n) / SR
    noise = bandpass(rng.standard_normal(n), 1200, 8000) * np.exp(-t / 0.07)
    tone = np.sin(2 * np.pi * 190 * t) * np.exp(-t / 0.05)
    return 0.8 * noise + 0.5 * tone


def drum_clap():
    n = int(0.3 * SR)
    t = np.arange(n) / SR
    env = np.zeros(n)
    for off in (0.0, 0.011, 0.022):
        tt = t - off
        env += np.where(tt >= 0, np.exp(-np.clip(tt, 0, None) / 0.006), 0)
    tt = t - 0.03
    env += np.where(tt >= 0, 0.6 * np.exp(-np.clip(tt, 0, None) / 0.09), 0)
    return bandpass(rng.standard_normal(n), 900, 3500) * env * 1.2


def drum_hat(open_hat=False):
    n = int((0.25 if open_hat else 0.06) * SR)
    t = np.arange(n) / SR
    decay = 0.09 if open_hat else 0.015
    return highpass(rng.standard_normal(n), 7000, 4) * np.exp(-t / decay)


# ---------------- 乐谱 ----------------

CHORDS = {
    "C": (36, [60, 64, 67]),
    "G": (43, [59, 62, 67]),
    "Am": (45, [60, 64, 69]),
    "F": (41, [60, 65, 69]),
    "Em": (40, [59, 64, 67]),
    "Dm": (38, [62, 65, 69]),
}

SECTION_A_CHORDS = [["C"], ["G"], ["Am"], ["F"], ["C"], ["G"], ["F", "G"], ["C"]]
SECTION_B_CHORDS = [["F"], ["G"], ["Em"], ["Am"], ["F"], ["G"], ["Dm"], ["G"]]

# 每小节 8 个八分音符；token = 音名:八分数，r = 休止
SECTION_A_MELODY = [
    "E5:1 G5:1 C6:2 G5:1 E5:1 G5:2",
    "D5:1 G5:1 B5:2 A5:1 G5:1 D5:2",
    "C5:1 E5:1 A5:2 G5:1 E5:1 C5:2",
    "F5:1 A5:1 C6:1 A5:1 G5:2 r:2",
    "E5:1 G5:1 C6:2 D6:1 C6:1 G5:2",
    "B5:1 A5:1 G5:1 A5:1 B5:2 D6:2",
    "C6:1 A5:1 F5:2 D5:1 G5:1 B5:2",
    "C6:4 r:2 G5:1 G5:1",
]
SECTION_B_MELODY = [
    "A4:2 C5:1 F5:2 E5:1 F5:2",
    "G5:3 F5:1 E5:1 D5:1 B4:2",
    "E5:2 G5:1 B5:2 A5:1 G5:2",
    "A5:3 G5:1 E5:2 C5:2",
    "F5:1 F5:1 A5:1 C6:2 A5:1 F5:2",
    "G5:1 G5:1 B5:1 D6:2 B5:1 G5:2",
    "F5:2 E5:1 D5:2 E5:1 F5:2",
    "G5:2 r:1 G5:1 A5:1 B5:1 D6:2",
]

# (旋律, 和弦, 是否加琶音, 是否加三度和声)
SONG = [
    (SECTION_A_MELODY, SECTION_A_CHORDS, False, False),
    (SECTION_B_MELODY, SECTION_B_CHORDS, False, False),
    (SECTION_A_MELODY, SECTION_A_CHORDS, True, False),
    (SECTION_B_MELODY, SECTION_B_CHORDS, True, True),
]


def parse_bar(bar: str):
    pos = 0
    notes = []
    for tok in bar.split():
        name, length = tok.split(":")
        length = int(length)
        if name != "r":
            notes.append((pos, length, note_to_midi(name)))
        pos += length
    assert pos == 8, f"小节长度应为 8 个八分音符: {bar}"
    return notes


# ---------------- 渲染 ----------------

class Track:
    def __init__(self, pan=0.0, gain=1.0):
        self.buf = np.zeros(TOTAL_N + TAIL_N)
        self.pan = pan
        self.gain = gain

    def add(self, start_sec, sig, vel=1.0):
        i = int(round(start_sec * SR))
        j = min(i + len(sig), len(self.buf))
        self.buf[i:j] += sig[: j - i] * vel

    def stereo(self):
        lg = np.cos((self.pan + 1) * np.pi / 4) * np.sqrt(2)
        rg = np.sin((self.pan + 1) * np.pi / 4) * np.sqrt(2)
        return self.buf * self.gain * lg, self.buf * self.gain * rg


def feedback_delay(x, delay_sec, fb, wet):
    d = int(delay_sec * SR)
    y = x.copy()
    for k in range(d, len(y), d):
        y[k:k + d] += fb * y[k - d:k][: len(y[k:k + d])]
    return x + wet * (y - x)


def render():
    lead = Track(0.0, 0.32)
    harm = Track(0.35, 0.16)
    stab = Track(0.0, 0.20)
    bass = Track(0.0, 0.42)
    arp = Track(-0.45, 0.09)
    kick = Track(0.0, 0.55)
    snare = Track(0.0, 0.22)
    clap = Track(0.1, 0.30)
    hat = Track(0.3, 0.10)

    k_s, sn_s, cl_s = drum_kick(), drum_snare(), drum_clap()
    hat_c, hat_o = drum_hat(False), drum_hat(True)

    bar_idx = 0
    for melody, chords, use_arp, use_harm in SONG:
        for b in range(8):
            t0 = bar_idx * BAR_SEC

            for pos, length, midi in parse_bar(melody[b]):
                st, dur = t0 + pos * EIGHTH, length * EIGHTH
                lead.add(st, inst_lead(midi, dur))
                if use_harm:
                    harm.add(st, inst_lead(diatonic_shift(midi, -2), dur))

            beats_per_chord = 4 // len(chords[b])
            for ci, cname in enumerate(chords[b]):
                root, triad = CHORDS[cname]
                c0 = t0 + ci * beats_per_chord * BEAT
                for e in range(beats_per_chord * 2):
                    bass_note = root if e % 2 == 0 else root + 12
                    bass.add(c0 + e * EIGHTH, inst_bass(bass_note, EIGHTH), 1.0 if e % 2 == 0 else 0.75)
                for bt in range(beats_per_chord):
                    stab.add(c0 + bt * BEAT + EIGHTH, inst_stab(triad))
                if use_arp:
                    tones = [triad[0] + 12, triad[1] + 12, triad[2] + 12, triad[1] + 12]
                    for s in range(beats_per_chord * 4):
                        arp.add(c0 + s * STEP16, inst_arp(tones[s % 4], STEP16))

            fill = (b == 7)
            for s in range(16):
                st = t0 + s * STEP16
                if s in (0, 8, 10):
                    kick.add(st, k_s)
                if s in (4, 12):
                    snare.add(st, sn_s)
                    clap.add(st, cl_s)
                if fill and s in (13, 14, 15):
                    snare.add(st, sn_s, 0.5 + 0.15 * (s - 13))
                if s == 14:
                    hat.add(st, hat_o, 0.8)
                elif s % 2 == 0:
                    hat.add(st, hat_c, 0.9 + 0.2 * rng.random())
                elif use_arp:
                    hat.add(st, hat_c, 0.35 + 0.15 * rng.random())

            bar_idx += 1

    lead.buf = feedback_delay(lead.buf, BEAT * 0.75, 0.3, 0.22)
    harm.buf = feedback_delay(harm.buf, BEAT * 0.75, 0.3, 0.22)

    left = np.zeros(TOTAL_N + TAIL_N)
    right = np.zeros(TOTAL_N + TAIL_N)
    for tr in (lead, harm, stab, bass, arp, kick, snare, clap, hat):
        l, r = tr.stereo()
        left += l
        right += r

    out = []
    for ch in (left, right):
        ch[:TAIL_N] += ch[TOTAL_N:]
        ch = ch[:TOTAL_N]
        # 先接上一份尾段再滤波，让循环点处的滤波器状态与曲中一致
        ch = highpass(np.concatenate([ch[-SR:], ch]), 30)[SR:]
        out.append(ch)
    mix = np.stack(out, axis=1)
    mix = np.tanh(mix * 1.1) / np.tanh(1.1)
    mix *= 0.89 / np.max(np.abs(mix))
    return mix


def main():
    mix = render()
    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    wavfile.write(OUT_PATH, SR, (mix * 32767).astype(np.int16))
    print(f"wrote {OUT_PATH} ({TOTAL_N / SR:.2f}s)")


if __name__ == "__main__":
    main()
