# M009-S03 Discussion Log: Grounded Drafting & Citations

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in `M009-S03-CONTEXT.md` — this log preserves the alternatives considered.

**Date:** 2026-05-17
**Phase:** M009-S03 — Grounded Drafting & Citations
**Areas discussed:** Evidence bundle for draft generation, Citation presentation in the draft review UI, Weak-grounding fallback behavior, Grounded draft shape

---

## Evidence bundle for draft generation

| Option | Description | Selected |
|--------|-------------|----------|
| Canonical-KB-only bundle | Highest trust and simplest source story, but loses useful resolved-case nuance and over-escalates when KB coverage is thin | |
| Mixed bundle with KB primary and resolved-case evidence secondary but labeled | One-pass compromise with explicit source classes, but easier for the model to overuse case evidence | |
| Unified mixed bundle with little source distinction | Simplest prompt assembly, but worst trust posture and highest policy-leakage risk | |
| Two-stage bundle: canonical first, assistive cases only when needed | KB-first trust model, intentional use of resolved cases, clean fallback branching, strongest long-term contract | ✓ |

**User choice:** Auto-selected recommended option based on the user's request for cohesive one-shot recommendations.
**Notes:** Locked as a canonical-first, two-stage drafting bundle. Resolved-case evidence is assistive only and enters the prompt only when canonical coverage is weak.

---

## Citation presentation in the draft review UI

| Option | Description | Selected |
|--------|-------------|----------|
| Inline citations inside the draft body | Strong claim-level traceability, but noisy and awkward in editable draft text | |
| Dedicated evidence section/card adjacent to the draft card in the rail | Clean draft body, visible grounding, best fit for the current `ConversationLive` shell | ✓ |
| Collapsible “Show support” panel inside the draft card | Keeps evidence local, but hides review-critical information behind optional disclosure | |
| Split view with draft body left and evidence pane right | Rich inspection model, but too heavy and disruptive for the current conversation shell | |

**User choice:** Auto-selected recommended option based on the user's request for cohesive one-shot recommendations.
**Notes:** Locked to an adjacent evidence section in the existing rail, echoing the evidence-first preview semantics established in M009-S02.

---

## Weak-grounding fallback behavior

| Option | Description | Selected |
|--------|-------------|----------|
| No draft; explicit escalation / manual-response state | Safest hard stop, but discards helpful operator scaffolding | |
| Draft anyway with prominent weak-grounding warning | Highest automation rate, but a major trust footgun and not a real safety mechanism | |
| Structured escalation recommendation instead of a customer-facing draft | Safe-by-default operator assist with explicit next-step guidance | ✓ |
| Customer-facing clarification-question draft when evidence is weak but not absent | Useful bounded recovery lane when the gap is missing customer context, not factual conflict | ✓ |

**User choice:** Auto-selected recommended policy package based on the user's request for cohesive one-shot recommendations.
**Notes:** Locked as a branching fallback policy:
- Strong canonical grounding -> normal grounded draft
- Weak but recoverable -> one focused clarification-question draft
- Empty, conflicting, assistive-only, or retrieval error -> structured escalation recommendation

---

## Grounded draft shape

| Option | Description | Selected |
|--------|-------------|----------|
| Concise reply draft plus linked citations only | Fastest and simplest, but weak for operator review and easy to over-trust | |
| Reply draft plus short evidence summary ahead of the reply | Better reviewability, but still compresses internal reasoning and evidence too tightly | |
| More source-echoing draft with quoted/paraphrased support passages | Highly legible grounding, but verbose and likely to blur policy vs assistive evidence | |
| Structured tri-part output: operator summary, proposed customer reply, evidence list | Best reviewability, clean source boundaries, and strongest future traceability | ✓ |

**User choice:** Auto-selected recommended option based on the user's request for cohesive one-shot recommendations.
**Notes:** Locked to a structured proposal artifact with separate internal summary, editable customer reply, and structured evidence list.

---

## the agent's Discretion

- Exact struct/module names for the grounding snapshot and proposal artifact
- Exact rules or thresholds for canonical coverage classification
- Exact copy for escalation labels, caution text, and summary phrasing
- Exact rail layout details and compact/mobile behavior, so long as evidence remains visible by default

## Deferred Ideas

- Inline citation chips in editable draft text
- Heavy split-pane analyst workbench inside the conversation shell
- Default “draft anyway with warning” behavior
- Letting assistive resolved-case evidence ground policy answers by itself

