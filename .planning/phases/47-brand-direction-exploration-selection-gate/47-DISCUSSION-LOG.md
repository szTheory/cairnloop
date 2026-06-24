# Phase 47 — Brand Direction Exploration · Discussion Log

**Date:** 2026-06-24
**Format:** Iterative visual "tournament" — throwaway HTML previews rendered in the session
scratchpad (never committed; not in the repo). The owner reviewed each round in a browser and
narrowed the field. This log is the **durable record of the selection gate** (LOGO-03 / TOKEN-01).

---

## The selection (locked)

| Gate item | Choice | Notes |
|---|---|---|
| **Logo direction** | **C3·6** — crowning-loop cairn, *ring-is-the-top-stone*, wider/flatter stones, compact ring | Loop = feedback/return; never infinity, never a cage |
| **Palette** | **Refined** | Evolve basalt/copper/paper + fix all Phase-46 AA failures |
| **Type** | **Keep current** — Atkinson + Fraunces + Martian | Fraunces confirmed for the wordmark |

---

## How we got there (round by round)

### Round 1 — four starting directions (A/B/C/D)
Showed the milestone-plan roster: (A) stacked cairn + wrapping loop, (B) negative-space loop, (C)
integrated typemark, (D) waymark/contour glyph — plus a palette preview (Current/Conservative/
Refined/Bolder) and a type preview (Fraunces vs Spectral).
**Owner:** picked **A (the stacked cairn)**, but wanted the **loop made structural** (worked into the
mark, not hung behind it). Liked **Fraunces**.

### Round 2 — nine ways to incorporate the loop into the cairn
Halo wrap, threaded, crowning, trail, orbit, one-line, feedback arrow, carved, tied.
**Owner:** picked only **V3 — Crowning loop** (the top stone becomes an open waymark ring). Asked to
go deep on that seed.

### Round 3 — ten crowning-ring treatments
C1 floating · C2 resting · C3 ring-is-top-stone · C4 spiral · C5 knotted · C6 tail · C7 contour ·
C8 donut · C9 ellipse · C10 open arch — plus a wordmark `oo`-ring echo and a 16px/mono favicon proof.
**Owner:** liked **C3 (ring is the top stone)** and **C10 (open arch)**, and liked the **`oo`-ring
echo**.

### Round 4 — refine the two finalists + fix the lockup
~6 cuts of C3 and ~6 of C10 (weight, gap, proportion, two-tone vs mono), a kerning ladder, and three
lockup arrangements. (Fixed a ring-top clipping bug from over-tight viewBox cropping; dropped a
tall 3-stone cut the owner disliked.)
**Owner:** locked **C3·6 — wider/flatter stones + compact ring.**

### Gate close-out — palette + type
**Owner:** **Palette = Refined**; **Type = keep current stack** (Fraunces confirmed; no workhorse
change → no font-budget work in Phase 48).

---

## Chosen mark — reference SVG (concept, NOT the production asset)

Phase 49 hand-authors the optimized, production-grade mark from this reference. Colors shown with the
**Refined** palette. The throwaway tournament files are gone after the scratchpad clears — this block
preserves the chosen geometry.

**Light (copper `#A8492A` ring, basalt `#141B19` stones):**

```svg
<svg width="48" height="48" viewBox="0 0 48 48" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Cairnloop">
  <!-- crowning loop: the ring IS the top stone -->
  <circle cx="24" cy="15" r="5.4" fill="none" stroke="#A8492A" stroke-width="2.8"/>
  <!-- mid stone -->
  <rect x="12" y="25" width="24" height="7" rx="3.5" fill="#1E2A24"/>
  <!-- base stone: widest & calm -->
  <rect x="7" y="34" width="34" height="8" rx="4" fill="#141B19"/>
</svg>
```

**Dark (copper `#D98A4A` ring, paper `#F4EEE2` stones, mid `#B7C0B2`):**

```svg
<svg width="48" height="48" viewBox="0 0 48 48" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Cairnloop">
  <circle cx="24" cy="15" r="5.4" fill="none" stroke="#D98A4A" stroke-width="2.8"/>
  <rect x="12" y="25" width="24" height="7" rx="3.5" fill="#B7C0B2"/>
  <rect x="7" y="34" width="34" height="8" rx="4" fill="#F4EEE2"/>
</svg>
```

**Mono / one-color (print) — single ink, copper dropped:** same geometry, `stroke` and `fill` all set
to `#141B19` (on light) or `#F4EEE2` (reversed on basalt).

### Lockup defaults (finalized in Phase 49)
- **Primary horizontal:** mark + `cairnloop` in Fraunces 600, **tight kern**, mark optically centered
  to the wordmark's cap height (round-3's loose gap was rejected as too wide).
- **Vertical / stacked:** mark centered above the wordmark.
- **Wordmark:** plain `cairnloop` in Fraunces. (The `oo`-ring echo / integrated-typemark treatment
  was explored and **dropped by the owner at finalization** — the mark stands alone.)
- **Favicon:** the ring + two stones hold legibility at 16px (verified in the tournament proof strip).

---

## Refined palette — illustrative values (Phase 48 finalizes exact hex)

| Token | Current | Refined | Why |
|---|---|---|---|
| basalt / text | `#18211F` | `#141B19` | deeper, more depth |
| paper / bg | `#F5F0E6` | `#F4EEE2` | warmer canvas |
| copper / primary | `#A94F30` | `#A8492A` | AA-safe for white text |
| muted text | `#677066` | `#5E665D` | fixes 4.52:1 fragile pairing |
| dark danger | `#E18C7D` | `#C96A55` | fixes 2.55:1 FAIL (white-on-danger) |

**Hard constraint carried to Phase 48:** the evolved palette must resolve every AA failure in
`46-CONTRAST-BASELINE.md` (3 text FAILs, the fragile muted near-miss, the dark danger button) and
classify the 12 border failures; Phase 48 SC4 re-verifies the full matrix.

---

## Rejected (for the record)
- Logo directions B, D and round-2 V1/V2/V4–V9; round-3 C1/C2/C4–C9; and the **open-arch C10** family
  — deleted from the contest in Phase 49.
- Palette **Conservative** (too static) and **Bolder** (risks the quiet/durable thesis).
- **Spectral** display alternative — Fraunces kept.
- **`oo`-ring echo / integrated typemark** — liked in rounds 3–4, but the owner dropped it at
  finalization; the wordmark stays plain `cairnloop`.

*This selection unlocks Phase 48 (apply Refined palette to `:root`) and Phase 49 (finalize the C3·6
asset family).*
