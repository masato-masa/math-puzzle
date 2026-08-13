"""BGM・効果音のプレースホルダーを合成して WAV で書き出す。

ライセンス上、既存の音源をそのまま使うわけにはいかないので、
「クラシックで上品」な方向性に寄せた単純なサイン波合成で仮当てする。
差し替えるときは同じファイル名で本物の音声ファイルに置き換えればよい
（SoundService 側はパスしか見ていない）。

標準ライブラリ（wave / math / struct）のみで完結させる。
"""

import math
import os
import struct
import wave

SR = 44100
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..",
                    "number_puzzle", "assets", "audio")


def write_wav(path, samples):
    """samples: -1.0〜1.0 の float リスト（モノラル）"""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        frames = b"".join(
            struct.pack("<h", max(-32768, min(32767, int(s * 32767))))
            for s in samples
        )
        w.writeframesraw(frames)


def sine(freq, t):
    return math.sin(2 * math.pi * freq * t)


def envelope_pluck(t, dur, attack=0.004, decay=None):
    """アタックが速く、指数的に減衰する「爪弾き」系エンベロープ"""
    decay = decay or dur
    if t < attack:
        return t / attack
    return math.exp(-(t - attack) / decay * 3.0)


def render_chime(freqs, dur, gains=None, attack=0.004, decay=None):
    """複数の正弦波を重ねた上品なチャイム音"""
    gains = gains or [1.0] * len(freqs)
    n = int(SR * dur)
    out = []
    for i in range(n):
        t = i / SR
        env = envelope_pluck(t, dur, attack=attack, decay=decay)
        v = sum(g * sine(f, t) for f, g in zip(freqs, gains))
        out.append(v * env / max(1.0, sum(gains)))
    return out


def render_sweep(f0, f1, dur, gain=0.5, attack=0.003):
    """周波数が滑らかに変化する「シュッ」という音（滑走・却下音向け）"""
    n = int(SR * dur)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / SR
        freq = f0 + (f1 - f0) * (t / dur)
        phase += 2 * math.pi * freq / SR
        env = envelope_pluck(t, dur, attack=attack, decay=dur * 0.6)
        out.append(gain * math.sin(phase) * env)
    return out


def render_noise_tick(dur, gain=0.25, seed=12345):
    """短いクリック音（低いランダムシード決定的ノイズ、当たる/塞がれる音向け）"""
    n = int(SR * dur)
    state = seed
    out = []
    for i in range(n):
        state = (1103515245 * state + 12345) & 0x7FFFFFFF
        r = (state / 0x7FFFFFFF) * 2 - 1
        t = i / SR
        env = math.exp(-t / (dur * 0.25))
        out.append(gain * r * env)
    return out


def mix(*tracks):
    n = max(len(t) for t in tracks)
    out = [0.0] * n
    for tr in tracks:
        for i, v in enumerate(tr):
            out[i] += v
    peak = max(1.0, max(abs(v) for v in out))
    return [v / peak * 0.9 for v in out]


def concat_with_gap(dur_gap, *tracks):
    gap = [0.0] * int(SR * dur_gap)
    out = []
    for i, tr in enumerate(tracks):
        out.extend(tr)
        if i < len(tracks) - 1:
            out.extend(gap)
    return out


# A4=440 を基準にした主要な音（優しい長調の響きにまとめる）
NOTE = {
    "C4": 261.63, "D4": 293.66, "E4": 329.63, "F4": 349.23,
    "G4": 392.00, "A4": 440.00, "B4": 493.88,
    "C5": 523.25, "D5": 587.33, "E5": 659.25, "G5": 783.99,
}


def gen_sfx():
    # 移動: 短く柔らかいクリック
    write_wav(os.path.join(OUT, "sfx_move.wav"),
              render_chime([NOTE["C5"]], 0.07, gains=[0.5], decay=0.05))

    # 滑走（氷）: シュッという滑らかなスイープ
    write_wav(os.path.join(OUT, "sfx_slide.wav"),
              render_sweep(520, 880, 0.18, gain=0.35))

    # 結合（計算成立）: 明るい2音のチャイム
    write_wav(os.path.join(OUT, "sfx_merge.wav"),
              render_chime([NOTE["E5"], NOTE["G5"]], 0.32, gains=[0.6, 0.5], decay=0.22))

    # 出口: 上品に抜けるような単音
    write_wav(os.path.join(OUT, "sfx_exit.wav"),
              render_chime([NOTE["C5"], NOTE["E5"]], 0.28, gains=[0.5, 0.35], decay=0.2))

    # 却下・ぶつかれない: 低く短いクリック
    write_wav(os.path.join(OUT, "sfx_blocked.wav"),
              mix(render_noise_tick(0.05, gain=0.18),
                  render_chime([220], 0.06, gains=[0.25], decay=0.04)))

    # 戻す（Undo）: 逆再生っぽい短いブリップ
    write_wav(os.path.join(OUT, "sfx_undo.wav"),
              render_sweep(700, 420, 0.12, gain=0.3))

    # クリア: 上昇する3音のアルペジオ
    win = concat_with_gap(0.03,
                           render_chime([NOTE["C5"]], 0.16, gains=[0.6], decay=0.12),
                           render_chime([NOTE["E5"]], 0.16, gains=[0.6], decay=0.12),
                           render_chime([NOTE["G5"], NOTE["C5"] * 2], 0.5,
                                        gains=[0.6, 0.3], decay=0.4))
    write_wav(os.path.join(OUT, "sfx_win.wav"), win)

    # 手数オーバー: 静かに下がる短い和音
    fail = render_chime([NOTE["A4"], NOTE["F4"]], 0.45, gains=[0.45, 0.45], decay=0.35)
    write_wav(os.path.join(OUT, "sfx_fail.wav"), fail)


BASS = {
    "C2": 65.41, "D2": 73.42, "E2": 82.41, "F2": 87.31,
    "G2": 98.00, "A2": 110.00, "B2": 123.47,
    "C3": 130.81, "D3": 146.83, "E3": 164.81, "F3": 174.61,
    "G3": 196.00, "A3": 220.00, "B3": 246.94,
}
ALL_NOTES = {**NOTE, **BASS}


def pluck(freq, dur, vel=0.5, harmonics=(1.0, 0.55, 0.22, 0.08), decay=None, attack=0.008):
    """減衰する倍音を重ねた、ハープ／チェレスタ寄りの上品な撥弦音。
    ドローン系のトレモロと違い音が持続しないので、不安な唸り（うなり）が出ない。"""
    decay = decay or dur * 0.85
    n = int(SR * dur)
    out = [0.0] * n
    hsum = sum(harmonics)
    for i in range(n):
        t = i / SR
        env = min(1.0, t / attack) * math.exp(-t / decay * 3.0)
        v = sum(h * sine(freq * k, t) for k, h in enumerate(harmonics, start=1))
        out[i] = (v / hsum) * env * vel
    return out


def mix_at(master, track, start_sample):
    for i, v in enumerate(track):
        idx = start_sample + i
        if idx < len(master):
            master[idx] += v


def gen_bgm():
    """上品で温かみのあるクラシック調のアルペジオ BGM。

    C - G - Am - F（いわゆる「王道進行」）を、チェレスタ風の撥弦音で
    分散和音（アルペジオ）にして奏でる。持続系のパッドではなく音を
    1つずつ減衰させる構成なので、トレモロのうなりによる不安な響きが出ない。
    ループの継ぎ目は等パワークロスフェードで滑らかに繋ぐ。
    """
    bpm = 96
    beat = 60.0 / bpm
    note_dur = beat / 2  # 8分音符
    bar_dur = beat * 4
    fade = 1.0

    progression = [
        # (和音の呼び方, アルペジオ音名の並び, ベース音)
        (["C4", "E4", "G4", "C5", "G4", "E4", "G4", "C5"], "C3"),
        (["G3", "B3", "D4", "G4", "D4", "B3", "D4", "G4"], "G2"),
        (["A3", "C4", "E4", "A4", "E4", "C4", "E4", "A4"], "A2"),
        (["F3", "A3", "C4", "F4", "C4", "A3", "C4", "F4"], "F2"),
    ]

    total_dur = bar_dur * len(progression)
    n_total = int(SR * (total_dur + fade))
    master = [0.0] * n_total

    t = 0.0
    for notes, bass_name in progression:
        bar_start = int(SR * t)
        # ベース: ゆったり伸びる低音（フワッとしたアタックで、うなりの出ない単純なサイン）
        bass = pluck(ALL_NOTES[bass_name] / 1.0, bar_dur * 1.3, vel=0.34,
                     harmonics=(1.0, 0.3), decay=bar_dur * 0.9, attack=0.25)
        mix_at(master, bass, bar_start)

        # アルペジオ: 8分音符で軽やかに
        for i, name in enumerate(notes):
            vel = 0.5 if i % 2 == 0 else 0.4  # 表拍を少し強く、クラシックらしい抑揚
            note = pluck(ALL_NOTES[name], note_dur * 2.2, vel=vel)
            mix_at(master, note, bar_start + int(SR * note_dur * i))
        t += bar_dur

    # 次の1周目冒頭（C の頭）を少しだけ先取りして描き、末尾とクロスフェードする
    lead_in = pluck(ALL_NOTES["C4"], fade * 2.2, vel=0.5)
    mix_at(master, lead_in, int(SR * total_dur))
    lead_bass = pluck(ALL_NOTES["C3"], fade * 2.2, vel=0.34, harmonics=(1.0, 0.3), attack=0.25)
    mix_at(master, lead_bass, int(SR * total_dur))

    n_dur = int(SR * total_dur)
    n_fade = int(SR * fade)
    out = list(master[:n_dur])
    tail = master[n_dur:n_dur + n_fade]
    for i in range(min(n_fade, len(tail))):
        a = i / n_fade
        out[i] = out[i] * math.cos(a * math.pi / 2) + tail[i] * math.sin(a * math.pi / 2)

    peak = max(1.0, max(abs(v) for v in out))
    out = [v / peak * 0.85 for v in out]

    write_wav(os.path.join(OUT, "bgm_loop.wav"), out)


if __name__ == "__main__":
    gen_sfx()
    gen_bgm()
    print("音源を書き出しました:", OUT)
