#!/usr/bin/env python3
"""Erzeugt die kachelbaren PBR-Detailtexturen für Frachtpilot (eigene Arbeit, frei nutzbar).

Je Satz zwei Bilder:
  *_n.png  Normal-Map (OpenGL-Konvention, Y nach oben)
  *_m.png  Maske: R = Hohlraum/AO, G = Rauheits-Variation (0,5 = neutral),
                  B = Kantenabrieb, A = Farbvariation je Platte (0,5 = neutral)

Aufruf: python3 tools/gen_textures.py  (schreibt nach textures/)
"""
import os
import numpy as np
from PIL import Image
from scipy import ndimage

OUT = os.path.join(os.path.dirname(__file__), "..", "textures")
N = 1024
rng = np.random.default_rng(7)


def fbm(n, octaves=5, base=8, seed=0):
    """Kachelbares Rauschen über Fourier-gefiltertes weißes Rauschen."""
    r = np.random.default_rng(seed)
    out = np.zeros((n, n))
    amp = 1.0
    f = base
    for _ in range(octaves):
        w = r.standard_normal((n, n))
        F = np.fft.fft2(w)
        ky = np.fft.fftfreq(n)[:, None] * n
        kx = np.fft.fftfreq(n)[None, :] * n
        k = np.sqrt(kx * kx + ky * ky)
        filt = np.exp(-((k / f) ** 2))
        layer = np.real(np.fft.ifft2(F * filt))
        layer /= layer.std() + 1e-9
        out += layer * amp
        amp *= 0.5
        f *= 2.0
    out = (out - out.min()) / (out.max() - out.min())
    return out


def wrap_blur(a, s):
    return ndimage.gaussian_filter(a, s, mode="wrap")


def to_normal(h, strength):
    gx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5
    gy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 0.5
    nx = -gx * strength
    ny = gy * strength  # Bildzeilen laufen nach unten, Y der Normal-Map nach oben
    nz = np.ones_like(h)
    ln = np.sqrt(nx * nx + ny * ny + nz * nz)
    n = np.stack([nx / ln, ny / ln, nz / ln], -1)
    return ((n * 0.5 + 0.5) * 255).clip(0, 255).astype(np.uint8)


def save(name, normal, mask):
    os.makedirs(OUT, exist_ok=True)
    Image.fromarray(normal, "RGB").save(os.path.join(OUT, name + "_n.png"), optimize=True)
    Image.fromarray((mask * 255).clip(0, 255).astype(np.uint8), "RGBA").save(os.path.join(OUT, name + "_m.png"), optimize=True)


class Panels:
    """Höhenfeld aus Platten mit Fasen, Fugen und Details."""

    def __init__(self, n):
        self.n = n
        self.h = np.zeros((n, n))
        self.rough = np.full((n, n), 0.5)
        self.tint = np.full((n, n), 0.5)
        self.yy, self.xx = np.mgrid[0:n, 0:n]

    def plate(self, x0, y0, x1, y1, level, bevel, groove):
        n = self.n
        sl = (slice(y0, y1), slice(x0, x1))
        yy = self.yy[sl]
        xx = self.xx[sl]
        d = np.minimum.reduce([xx - x0 + 0.5, x1 - 0.5 - xx, yy - y0 + 0.5, y1 - 0.5 - yy])
        prof = np.clip((d - groove) / bevel, 0.0, 1.0)
        prof = np.sin(prof * np.pi / 2)
        self.h[sl] = np.where(d < groove, -0.35, level * prof + (prof - 1.0) * 0.25)
        self.rough[sl] = 0.5 + rng.uniform(-0.18, 0.18)
        self.tint[sl] = 0.5 + rng.uniform(-0.14, 0.14)
        return d

    def rivets(self, x0, y0, x1, y1, inset, step, r, height):
        pts = []
        for x in np.arange(x0 + inset, x1 - inset + 1, step):
            pts += [(x, y0 + inset), (x, y1 - inset)]
        for y in np.arange(y0 + inset + step, y1 - inset - step + 1, step):
            pts += [(x0 + inset, y), (x1 - inset, y)]
        for (px, py) in pts:
            self.bump(px, py, r, height)

    def bump(self, px, py, r, height):
        x0, x1 = int(px - r - 2), int(px + r + 3)
        y0, y1 = int(py - r - 2), int(py + r + 3)
        x0, y0 = max(x0, 0), max(y0, 0)
        x1, y1 = min(x1, self.n), min(y1, self.n)
        yy = self.yy[y0:y1, x0:x1]
        xx = self.xx[y0:y1, x0:x1]
        d = np.sqrt((xx - px) ** 2 + (yy - py) ** 2) / r
        dome = np.where(d < 1.0, np.sqrt(np.clip(1 - d * d, 0, 1)) * height, 0.0)
        self.h[y0:y1, x0:x1] += dome

    def slots(self, x0, y0, x1, y1, count, vertical, depth):
        w = (x1 - x0) if not vertical else (y1 - y0)
        for i in range(count):
            t0 = int(i * w / count + w / count * 0.25)
            t1 = int(i * w / count + w / count * 0.75)
            if vertical:
                ya, yb, xa, xb = y0 + t0, y0 + t1, x0 + 6, x1 - 6
            else:
                xa, xb, ya, yb = x0 + t0, x0 + t1, y0 + 6, y1 - 6
            sl = (slice(ya, yb), slice(xa, xb))
            yy = self.yy[sl]
            xx = self.xx[sl]
            d = np.minimum.reduce([xx - xa + 0.5, xb - 0.5 - xx, yy - ya + 0.5, yb - 0.5 - yy])
            self.h[sl] -= depth * np.clip(d / 3.0, 0, 1)
            self.rough[sl] = 0.75

    def ring(self, cx, cy, r, w, depth):
        d = np.abs(np.sqrt((self.xx - cx) ** 2 + (self.yy - cy) ** 2) - r)
        self.h -= depth * np.clip(1 - d / w, 0, 1)

    def inset(self, x0, y0, x1, y1, depth, bevel):
        sl = (slice(y0, y1), slice(x0, x1))
        yy = self.yy[sl]
        xx = self.xx[sl]
        d = np.minimum.reduce([xx - x0 + 0.5, x1 - 0.5 - xx, yy - y0 + 0.5, y1 - 0.5 - yy])
        self.h[sl] -= depth * np.clip(d / bevel, 0, 1)

    def raised(self, x0, y0, x1, y1, height, bevel):
        self.inset(x0, y0, x1, y1, -height, bevel)

    def finish(self, strength, grime_amt=1.0):
        h = self.h + (fbm(self.n, 4, 40, 3) - 0.5) * 0.04
        nrm = to_normal(h, strength)
        blur = wrap_blur(h, 6)
        cav = np.clip(1.0 - (blur - h) * 2.2, 0.0, 1.0)
        cav = cav * 0.85 + 0.15 * np.clip(1.0 - (wrap_blur(h, 20) - h) * 1.2, 0, 1)
        edge = np.clip((h - blur) * 6.0, 0.0, 1.0)
        grime = fbm(self.n, 5, 6, 11)
        rough = np.clip(self.rough + (grime - 0.5) * 0.25 * grime_amt + (1 - cav) * 0.3, 0, 1)
        mask = np.stack([cav, rough, edge, self.tint], -1)
        return nrm, mask


def subdivide(p, x0, y0, x1, y1, depth, minsz, on_leaf):
    w, h = x1 - x0, y1 - y0
    if depth <= 0 or (w < minsz * 2 and h < minsz * 2) or (depth < 3 and rng.random() < 0.25):
        on_leaf(x0, y0, x1, y1)
        return
    if (w > h and w >= minsz * 2) or h < minsz * 2:
        s = int(x0 + w * rng.choice([0.25, 0.375, 0.5, 0.625, 0.75]))
        s = int(round(s / 16) * 16)
        if s <= x0 + minsz // 2 or s >= x1 - minsz // 2:
            on_leaf(x0, y0, x1, y1)
            return
        subdivide(p, x0, y0, s, y1, depth - 1, minsz, on_leaf)
        subdivide(p, s, y0, x1, y1, depth - 1, minsz, on_leaf)
    else:
        s = int(y0 + h * rng.choice([0.25, 0.375, 0.5, 0.625, 0.75]))
        s = int(round(s / 16) * 16)
        if s <= y0 + minsz // 2 or s >= y1 - minsz // 2:
            on_leaf(x0, y0, x1, y1)
            return
        subdivide(p, x0, y0, x1, s, depth - 1, minsz, on_leaf)
        subdivide(p, x0, s, x1, y1, depth - 1, minsz, on_leaf)


def hull():
    """Rumpfplatten (Kachel = 4 m): versetzte Platten, Nieten, Lüftungsschlitze, Wartungsluken."""
    p = Panels(N)

    def leaf(x0, y0, x1, y1):
        p.plate(x0, y0, x1, y1, rng.uniform(0.05, 0.25), 7.0, 2.2)
        w, h = x1 - x0, y1 - y0
        r = rng.random()
        if min(w, h) >= 96 and r < 0.18:
            p.slots(x0 + w // 5, y0 + h // 5, x1 - w // 5, y1 - h // 5, int(rng.integers(4, 9)), h > w, 0.35)
        elif min(w, h) >= 128 and r < 0.3:
            cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
            rr = min(w, h) * 0.3
            p.ring(cx, cy, rr, 2.5, 0.35)
            for a in range(8):
                ang = a * np.pi / 4
                p.bump(cx + np.cos(ang) * (rr + 9), cy + np.sin(ang) * (rr + 9), 3.2, 0.25)
        elif min(w, h) >= 80 and r < 0.5:
            m = int(min(w, h) * 0.18)
            p.inset(x0 + m, y0 + m, x1 - m, y1 - m, 0.12, 5.0)
        elif min(w, h) >= 64 and r < 0.62:
            gw, gh = int(w * rng.uniform(0.2, 0.4)), int(h * rng.uniform(0.2, 0.4))
            gx, gy = int(x0 + w * 0.2), int(y0 + h * 0.2)
            p.raised(gx, gy, gx + gw, gy + gh, 0.18, 4.0)
        if rng.random() < 0.7:
            p.rivets(x0, y0, x1, y1, 9, 28, 3.0, 0.22)

    subdivide(p, 0, 0, N, N, 6, 64, leaf)
    nrm, mask = p.finish(9.0)
    save("hull", nrm, mask)


def deck():
    """Bodenplatten (Kachel = 2 m): 4×4 Platten, abwechselnd Riffelblech, Gitter und glatt."""
    p = Panels(N)
    s = N // 4
    for j in range(4):
        for i in range(4):
            x0, y0 = i * s, j * s
            p.plate(x0, y0, x0 + s, y0 + s, 0.12, 5.0, 2.0)
            kind = (i + j * 3 + (j // 2)) % 3
            if kind == 0:
                # Riffelblech: diagonale Tränen
                for yy in range(y0 + 14, y0 + s - 10, 22):
                    for xx in range(x0 + 14 + (11 if (yy // 22) % 2 else 0), x0 + s - 10, 22):
                        ang = np.pi / 4 if ((xx // 22 + yy // 22) % 2) else -np.pi / 4
                        for t in np.linspace(-6, 6, 7):
                            p.bump(xx + np.cos(ang) * t, yy + np.sin(ang) * t, 2.6, 0.12)
            elif kind == 1:
                p.slots(x0 + 18, y0 + 18, x0 + s - 18, y0 + s - 18, 9, True, 0.5)
            else:
                p.inset(x0 + 40, y0 + 40, x0 + s - 40, y0 + s - 40, 0.06, 6.0)
            for (bx, by) in [(x0 + 12, y0 + 12), (x0 + s - 12, y0 + 12), (x0 + 12, y0 + s - 12), (x0 + s - 12, y0 + s - 12)]:
                p.bump(bx, by, 4.5, 0.3)
    nrm, mask = p.finish(8.0, 1.4)
    save("deck", nrm, mask)


def wall():
    """Wandverkleidung (Kachel = 3,2 m breit × 3,2 m hoch): senkrechte Paneele mit Rahmen und Lüftern."""
    p = Panels(N)
    cols = 2
    s = N // cols
    for i in range(cols):
        x0 = i * s
        rows = [0, int(N * 0.35), int(N * 0.62), N]
        for k in range(3):
            y0, y1 = rows[k], rows[k + 1]
            p.plate(x0, y0, x0 + s, y1, 0.14, 8.0, 2.5)
            m = 34
            if k == 1 and i == 0:
                p.slots(x0 + 60, y0 + 40, x0 + s - 60, y1 - 40, 7, True, 0.4)
            else:
                p.inset(x0 + m, y0 + m, x0 + s - m, y1 - m, 0.1, 6.0)
                p.rivets(x0, y0, x0 + s, y1, 16, 40, 3.2, 0.2)
    nrm, mask = p.finish(7.0, 0.8)
    save("wall", nrm, mask)


def scratches():
    """Feine Kratzer und Bürstung für dunkles Metall (Kachel = 2 m)."""
    h = np.zeros((N, N))
    base = fbm(N, 3, 30, 21)
    # gebürstet: stark gestrecktes Rauschen
    r = np.random.default_rng(5).standard_normal((N, N))
    brushed = ndimage.gaussian_filter(r, (0.6, 30), mode="wrap")
    brushed /= brushed.std()
    h += brushed * 0.02 + base * 0.05
    yy, xx = np.mgrid[0:N, 0:N]
    for _ in range(140):
        x, y = rng.uniform(0, N, 2)
        ang = rng.uniform(0, np.pi)
        ln = rng.uniform(20, 160)
        dx, dy = np.cos(ang), np.sin(ang)
        px = (xx - x + N / 2) % N - N / 2
        py = (yy - y + N / 2) % N - N / 2
        along = px * dx + py * dy
        across = np.abs(-px * dy + py * dx)
        m = (np.abs(along) < ln / 2) & (across < 1.2)
        h[m] -= 0.05
    nrm = to_normal(h, 12.0)
    cav = np.clip(1.0 - (wrap_blur(h, 3) - h) * 6.0, 0, 1)
    rough = np.clip(0.5 + (base - 0.5) * 0.4 + brushed * 0.03, 0, 1)
    mask = np.stack([cav, rough, np.zeros_like(h), np.full_like(h, 0.5)], -1)
    save("metal", nrm, mask)


if __name__ == "__main__":
    hull()
    deck()
    wall()
    scratches()
    print("ok")
