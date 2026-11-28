"""合成「建造完成」UI 音效候选（纯合成，无第三方采样，可自由使用）。

风格参照 RTS 的 construction-complete：石头落定的闷响 + 上行的钟琴音。
输出格式与 GuildMaster-Godot-src/audio/guild_*.wav 保持一致：
单声道 / 44100 Hz / 16-bit，峰值归一化到 -13 dBFS。

用法：
    python tools/gen_guild_build_sfx.py [输出目录]
默认输出到 .tmp/sfx/。
"""

import os
import sys
import wave

import numpy as np

SR = 44100
PEAK_DBFS = -13.0


def _lowpass(x, cutoff, poles=2):
    """一阶级联低通（无 scipy 依赖）。"""
    a = 1.0 - np.exp(-2.0 * np.pi * cutoff / SR)
    y = x.astype(np.float64).copy()
    for _ in range(poles):
        out = np.empty_like(y)
        acc = 0.0
        for i in range(y.size):  # 44.1kHz 短音效，纯 Python 循环也够快
            acc += a * (y[i] - acc)
            out[i] = acc
        y = out
    return y


def _lowpass_fast(x, cutoff, poles=2):
    """向量化一阶低通（用 lfilter 的递推不可向量化，这里用 FFT 幅频近似）。"""
    n = x.size
    freqs = np.fft.rfftfreq(n, 1.0 / SR)
    resp = (1.0 / np.sqrt(1.0 + (freqs / cutoff) ** 2)) ** poles
    return np.fft.irfft(np.fft.rfft(x) * resp, n)


def _t(seconds):
    return np.arange(int(seconds * SR)) / SR


def _bell(duration, freq, tau, amp=1.0, ratios=(1.0, 2.0, 2.76, 5.40, 8.93),
          amps=(1.0, 0.50, 0.26, 0.11, 0.045)):
    """钟琴音：非谐分音 + 各分音独立衰减。"""
    t = _t(duration)
    out = np.zeros_like(t)
    for r, a in zip(ratios, amps):
        if freq * r >= SR / 2:
            continue
        # 高通分音衰减更快，听感更接近真实金属体
        partial_tau = tau / (1.0 + 0.55 * (r - 1.0))
        out += a * np.sin(2 * np.pi * freq * r * t) * np.exp(-t / partial_tau)
    # 起音微削波，避免咔哒声
    attack = int(0.004 * SR)
    if attack > 1:
        out[:attack] *= np.linspace(0.0, 1.0, attack)
    return amp * out


def _stone_hit(duration=0.28, hardness=1.0):
    """石头/木料落定：噪声瞬态 + 低频闷响。"""
    t = _t(duration)
    rng = np.random.default_rng(4706)
    noise = rng.standard_normal(t.size)
    body = _lowpass_fast(noise, 750.0 * hardness, poles=3) * np.exp(-t / 0.055)
    body /= max(np.abs(body).max(), 1e-9)
    thump = np.sin(2 * np.pi * (68.0 * np.exp(-t / 0.09) + 42.0) * t) * np.exp(-t / 0.10)
    debris = _lowpass_fast(noise, 5200.0, poles=2) - _lowpass_fast(noise, 1400.0, poles=2)
    debris *= np.exp(-t / 0.14) * 0.22
    debris /= max(np.abs(debris).max(), 1e-9)
    return 0.85 * body + 0.38 * thump + 0.07 * debris


def _reverb(x, tau=0.26, wet=0.16, seed=7):
    rng = np.random.default_rng(seed)
    ir_len = int(0.42 * SR)
    ir_t = np.arange(ir_len) / SR
    ir = rng.standard_normal(ir_len) * np.exp(-ir_t / tau)
    ir = _lowpass_fast(ir, 4200.0, poles=3)
    ir[: int(0.012 * SR)] = 0.0  # 预延迟
    ir /= np.sqrt((ir ** 2).sum())
    n = x.size + ir_len - 1
    nfft = 1 << (n - 1).bit_length()
    wet_sig = np.fft.irfft(np.fft.rfft(x, nfft) * np.fft.rfft(ir, nfft), nfft)[: x.size]
    return (1.0 - wet) * x + wet * wet_sig


def _place(track, sig, at):
    start = int(at * SR)
    end = min(track.size, start + sig.size)
    track[start:end] += sig[: end - start]
    return track


def variant_a():
    """石头闷响 + A4→E5 纯五度钟琴（最接近经典 construction complete）。"""
    track = np.zeros(int(1.05 * SR))
    _place(track, _stone_hit(), 0.0)
    _place(track, _bell(0.70, 440.00, 0.30, amp=0.55), 0.09)
    _place(track, _bell(0.85, 659.25, 0.34, amp=0.80), 0.27)
    return track


def variant_b():
    """石头闷响 + C5→E5 大三度，尾音更长、更柔。"""
    track = np.zeros(int(1.10 * SR))
    _place(track, _stone_hit(hardness=0.85), 0.0)
    _place(track, _bell(0.75, 523.25, 0.32, amp=0.50), 0.08)
    _place(track, _bell(0.95, 783.99, 0.40, amp=0.78), 0.25)
    return track


def variant_c():
    """更重的落地 + G4→D5 四度，带低频余震，适合「大型建造」。"""
    track = np.zeros(int(1.20 * SR))
    _place(track, _stone_hit(0.36, hardness=0.70) * 1.1, 0.0)
    rumble = _lowpass_fast(np.random.default_rng(11).standard_normal(int(0.55 * SR)), 90.0, poles=3)
    rumble *= np.exp(-np.arange(rumble.size) / SR / 0.18)
    rumble /= max(np.abs(rumble).max(), 1e-9)
    _place(track, 0.30 * rumble, 0.0)
    _place(track, _bell(0.80, 392.00, 0.34, amp=0.55), 0.12)
    _place(track, _bell(1.00, 587.33, 0.42, amp=0.80), 0.30)
    return track


def _highpass(x, cutoff, poles=2):
    return x - _lowpass_fast(_lowpass_fast(x, cutoff, 1), cutoff, poles - 1) if poles > 1 \
        else x - _lowpass_fast(x, cutoff, 2)


def normalize(x, peak_db=PEAK_DBFS, target_rms_db=-24.3):
    """混响 + 高通 + 软限幅，对齐现有 guild_*.wav 的响度（峰值约 -13、RMS 约 -24.3 dBFS）。

    drive 用二分法求解，保证不同变体响度一致。
    """
    peak_db_target = peak_db
    x = _reverb(x)
    x = _highpass(x, 42.0, poles=2)  # 去掉听不见的次低频，把能量让给钟琴
    x = x / max(np.abs(x).max(), 1e-9)

    def shaped(drive):
        y = np.tanh(drive * x) / np.tanh(drive)
        y = y / max(np.abs(y).max(), 1e-9)
        return y * (10 ** (peak_db_target / 20.0))

    def rms_of(y):
        return 20 * np.log10(max(np.sqrt((y ** 2).mean()), 1e-9))

    lo, hi = 1.0, 8.0
    if rms_of(shaped(lo)) >= target_rms_db:
        return shaped(lo)  # 轻微压缩就够，保持瞬态
    if rms_of(shaped(hi)) <= target_rms_db:
        return shaped(hi)  # 压到极限仍达不到目标，取最响的一档
    for _ in range(28):
        mid = 0.5 * (lo + hi)
        if rms_of(shaped(mid)) > target_rms_db:
            hi = mid
        else:
            lo = mid
    return shaped(0.5 * (lo + hi))


def fade_tail(x, ms=12):
    n = min(x.size, int(SR * ms / 1000.0))
    if n > 1:
        x[-n:] *= np.linspace(1.0, 0.0, n)
    return x


def write_wav(path, x):
    data = np.clip(np.round(x * 32767.0), -32768, 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def main():
    here = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out_dir = sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, ".tmp", "sfx")
    os.makedirs(out_dir, exist_ok=True)
    for name, fn in (("a", variant_a), ("b", variant_b), ("c", variant_c)):
        x = fade_tail(normalize(fn()))
        path = os.path.join(out_dir, "guild_build_%s.wav" % name)
        write_wav(path, x)
        rms = 20 * np.log10(max(np.sqrt((x ** 2).mean()), 1e-9))
        print("%s  %.2fs  peak=%.2f dBFS  rms=%.2f dBFS" % (
            os.path.basename(path), x.size / SR, 20 * np.log10(np.abs(x).max()), rms))


if __name__ == "__main__":
    main()
