// Shared "squeegee art" engine: soapy foam layer + letters cut out by a squeegee.
// Used by the homepage hero and by squeegee-art.html (video renderer).
(function (g) {
  function rng(seed) {
    let s = (seed >>> 0) || 1;
    return () => { s ^= s << 13; s ^= s >>> 17; s ^= s << 5; return ((s >>> 0) % 100000) / 100000; };
  }

  // Paints soapy foam on ctx (w x h in CSS px). Deterministic for a given seed.
  function paintFoam(ctx, w, h, seed) {
    const r = rng(seed);
    const u = Math.max(w, h) / 640;
    ctx.save();
    ctx.globalCompositeOperation = 'source-over';
    ctx.clearRect(0, 0, w, h);
    const gr = ctx.createLinearGradient(0, 0, 0, h);
    gr.addColorStop(0, 'rgba(233,239,236,0.94)');
    gr.addColorStop(1, 'rgba(220,228,224,0.91)');
    ctx.fillStyle = gr;
    ctx.fillRect(0, 0, w, h);
    // loose soap arcs
    for (let i = 0; i < 110; i++) {
      ctx.beginPath();
      ctx.strokeStyle = `rgba(255,255,255,${0.25 + r() * 0.45})`;
      ctx.lineWidth = (1 + r() * 6) * u;
      const a = r() * Math.PI * 2;
      ctx.arc(r() * w, r() * h, (20 + r() * 300) * u, a, a + 0.6 + r() * 1.8);
      ctx.stroke();
    }
    // concentric swirls from the scrubber
    for (let c = 0; c < 9; c++) {
      const cx = r() * w, cy = r() * h, a0 = r() * Math.PI * 2;
      for (let j = 0; j < 16; j++) {
        ctx.beginPath();
        ctx.strokeStyle = `rgba(255,255,255,${0.35 + r() * 0.4})`;
        ctx.lineWidth = (1.5 + r() * 2.5) * u;
        const a = a0 + r() * 0.5;
        ctx.arc(cx, cy, (12 + j * 10) * u, a, a + 1.3 + r() * 2.2);
        ctx.stroke();
      }
    }
    // drips
    for (let i = 0; i < 30; i++) {
      const x = r() * w, y = r() * h * 0.7, len = (30 + r() * 150) * u, dw = (2 + r() * 3) * u;
      ctx.fillStyle = 'rgba(255,255,255,0.75)';
      ctx.fillRect(x, y, dw, len);
      ctx.beginPath(); ctx.arc(x + dw / 2, y + len, dw * 1.2, 0, Math.PI * 2); ctx.fill();
    }
    // bubbles / speckles
    const n = Math.round(w * h / 300);
    for (let i = 0; i < n; i++) {
      ctx.fillStyle = `rgba(255,255,255,${r() * 0.85})`;
      const s = (0.8 + r() * 1.6) * u;
      ctx.fillRect(r() * w, r() * h, s, s);
    }
    ctx.restore();
  }

  // Lays out stacked uppercase lines centred in w x h. Returns one entry per letter.
  function layoutWord(ctx, w, h, lines, family) {
    const probe = 100;
    ctx.save();
    ctx.font = `900 ${probe}px ${family}`;
    const track = 0.03;
    const lineW = l => [...l].reduce((s, ch) => s + ctx.measureText(ch).width, 0) + track * probe * (l.length - 1);
    const maxW = Math.max(...lines.map(lineW));
    const size = Math.min(w * 0.84 / maxW * probe, h * 0.8 / (lines.length * 0.9));
    ctx.font = `900 ${size}px ${family}`;
    const capM = ctx.measureText('D');
    const cap = capM.actualBoundingBoxAscent;
    const lineH = size * 0.9;
    const top0 = (h - (lineH * (lines.length - 1) + cap)) / 2;
    const out = [];
    lines.forEach((line, li) => {
      const lw = [...line].reduce((s, ch) => s + ctx.measureText(ch).width, 0) + track * size * (line.length - 1);
      let x = (w - lw) / 2;
      const base = top0 + cap + li * lineH;
      for (const ch of line) {
        const m = ctx.measureText(ch);
        out.push({ ch, x, base, top: base - cap, lh: cap + Math.max(m.actualBoundingBoxDescent, 0), wd: m.width,
                   font: ctx.font, pad: size * 0.04, rim: Math.max(2, size * 0.022) });
        x += m.width + track * size;
      }
    });
    ctx.restore();
    return out;
  }

  // Cuts the top fraction p (0..1) of a letter out of the foam, with a foam ridge along the edge.
  function cutLetter(ctx, L, p) {
    if (p <= 0) return;
    ctx.save();
    ctx.beginPath();
    ctx.rect(L.x - L.pad, L.top - L.pad, L.wd + 2 * L.pad, (L.lh + 2 * L.pad) * Math.min(p, 1));
    ctx.clip();
    ctx.font = L.font;
    ctx.textBaseline = 'alphabetic';
    ctx.globalCompositeOperation = 'destination-out';
    ctx.fillStyle = '#000';
    ctx.fillText(L.ch, L.x, L.base);
    ctx.globalCompositeOperation = 'source-over';
    ctx.lineJoin = 'round';
    ctx.strokeStyle = 'rgba(255,255,255,0.92)';
    ctx.shadowColor = 'rgba(255,255,255,0.9)';
    ctx.shadowBlur = L.rim * 1.6;
    ctx.lineWidth = L.rim;
    ctx.strokeText(L.ch, L.x, L.base);
    ctx.restore();
  }

  // Squeegee with the rubber blade centred on (cx, y).
  function drawSqueegee(ctx, cx, y, width) {
    const bw = width, x = cx - bw / 2;
    ctx.save();
    ctx.shadowColor = 'rgba(0,0,0,0.35)';
    ctx.shadowBlur = bw * 0.08;
    ctx.shadowOffsetY = bw * 0.04;
    ctx.fillStyle = '#22D36B';
    const hw = bw * 0.16, hh = bw * 0.38;
    ctx.beginPath();
    ctx.roundRect ? ctx.roundRect(cx - hw / 2, y - bw * 0.1 - hh, hw, hh, hw * 0.35) : ctx.rect(cx - hw / 2, y - bw * 0.1 - hh, hw, hh);
    ctx.fill();
    ctx.shadowColor = 'transparent';
    ctx.fillStyle = '#0A7A3B';
    ctx.fillRect(cx - hw * 0.2, y - bw * 0.1 - hh * 0.85, hw * 0.4, hh * 0.6);
    ctx.fillStyle = '#9BA39C';
    ctx.fillRect(x + bw * 0.02, y - bw * 0.1, bw * 0.96, bw * 0.08);
    ctx.fillStyle = '#121412';
    ctx.fillRect(x, y - bw * 0.025, bw, bw * 0.05);
    ctx.restore();
  }

  g.Foam = { rng, paintFoam, layoutWord, cutLetter, drawSqueegee };
})(window);
