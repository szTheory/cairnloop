---
phase: 12
slug: in-thread-quick-fix-ops-closure
status: draft
shadcn_initialized: false
preset: none
created: 2026-05-22
---

# Phase 12 — UI Design Contract

> Visual and interaction contract for the in-thread KB quick-fix entrypoint and bounded ops closure surfaces in Phoenix LiveView. This slice adds a conversation-native maintenance launch card, preserves the shared review lane as workflow truth, and exposes calm fail-closed status without creating a second dashboard.

---

## Design System

| Property | Value |
|----------|-------|
| Tool | none; manual Phoenix LiveView contract |
| Preset | not applicable |
| Component library | none; LiveView function components and existing page modules |
| Icon library | Heroicons or equivalent inline SVG only for evidence, state, and handoff cues |
| Font | `--cl-font-sans` for all operator UI; `--cl-font-mono` only for telemetry keys, digests, or timestamps shown as secondary metadata |

---

## Layout Contract

- Add one new quick-fix card inside the existing `ConversationLive` evidence rail. Do not place the primary launch action in the reply composer, page header, or generic tool execution list.
- Desktop (`>= 1024px`): preserve the current two-column conversation layout with the message timeline as the dominant pane and the evidence rail locked to `352px` width.
- The quick-fix card sits in the evidence rail below conversation evidence/context and above any historical draft audit cards so the maintenance launch reads as evidence-adjacent, not as a reply action.
- The quick-fix card is a single contained surface, not an accordion stack and not a modal. Operators should understand the current maintenance state without leaving the thread.
- Within the card, use a fixed vertical order:
  1. KB maintenance eyebrow and title
  2. one-sentence operator summary
  3. typed evidence layer summary
  4. blocked or shell reason callout when applicable
  5. primary action row
  6. follow-through status rail
- Mobile (`< 1024px`): keep the conversation stacked; place the quick-fix card directly after the context pane and before draft audit cards.
- Do not add a separate Phase 12 queue, drawer, or operations dashboard. The second surface remains the existing `/knowledge-base/suggestions` review lane only.

---

## Component Contract

- `quick_fix_card/1`: the only new conversation-thread launch surface. Owns summary copy, evidence counts, fallback reason, primary CTA, and link to the shared review lane.
- `evidence_layer_list/1`: show exactly three layers in this order:
  - `Thread context`
  - `Canonical retrieval`
  - `Resolved case assists`
- `evidence_layer_row/1`: every row must show layer label, trust role, and bounded count or availability state. Never merge the three layers into one unlabeled evidence blob.
- `quick_fix_reason_callout/1`: compact callout for shell or blocked states. This is required when canonical grounding is partial or unavailable.
- `quick_fix_action_row/1`: contains one primary CTA and at most one secondary text link.
  - Primary action is stateful: `Start KB quick fix`, `Open review task`, or `Open manual draft`.
  - Secondary link is optional: `View maintenance lane`.
- `quick_fix_status_rail/1`: compact vertical rail or stacked chips inside the card showing the current lane stage after initiation.
- `review_lane_status_block/1`: extend the shared review-task detail view with quick-fix origin metadata and clearer publish/reindex follow-through copy. Do not create a new detail page.
- `status_chip/1`: bounded operator-visible state indicator for one workflow stage only. Chips must be text-first, not color-only.
- `manual_path_notice/1`: plain inline guidance used only when the lane is blocked or when a shell routes to manual authoring.

---

## Interaction Contract

- Primary launch is a button inside the quick-fix card. Clicking it must create or reuse the durable suggestion plus review-task lane, then navigate into `/knowledge-base/suggestions` with the selected task.
- Launch action must be idempotent. Repeated clicks while work already exists reopen the existing maintenance lane instead of creating duplicate tasks.
- The conversation page remains the starting surface. Do not open a composer overlay, modal wizard, or inline markdown editor from the thread.
- The thread card must expose the result of the launch attempt in place before or alongside navigation:
  - success into review lane
  - shell created
  - blocked/manual required
- When a draft shell is created, the operator still lands in the shared review lane so the shell remains inside the same audit trail.
- When the system is blocked because canonical evidence cannot be built or anchors fail, the thread card must keep the operator in-context and present a manual path with explicit reason text.
- Secondary navigation from the thread card is always explicit. Do not auto-redirect on passive status refreshes.
- Thread reply drafting must remain intact. The quick-fix action cannot clear the reply textarea, mutate existing conversation drafts, or steal generic keyboard handling.
- Review-lane actions remain the existing Phase 11 actions: approve, reject, defer, open for edit, publish. Phase 12 does not add a shortcut that combines approval and publish.

---

## State Contract

- `idle`: no maintenance item exists yet for the current conversation evidence package. Card shows summary, layer availability, and `Start KB quick fix`.
- `preparing`: action acknowledged and work in progress. Keep the card visible with a non-blocking progress message; do not replace the whole rail with a spinner.
- `ready`: suggestion plus review task created with citation-eligible canonical grounding. Primary action becomes `Open review task`.
- `shell_created`: a reviewable draft shell exists because the work item is valid but grounding is partial. Card must show the missing-grounding reason and still route to the review lane.
- `blocked_manual_required`: canonical snapshot, citation anchors, or policy guardrails failed. Card must show the blocking reason and expose `Open manual draft` as the primary safe next step.
- `approved_ready_to_publish`: show that review approved the work, but publish is still pending. Never label this as done.
- `published`: show that the KB revision is published, but reindex follow-through may still be pending.
- `reindexing`: show active follow-through separately from publish.
- `reindexed`: terminal success state for this phase.
- `retry_needed`: publish or reindex follow-through failed and needs operator attention in the review lane.

Rules:

- Never collapse `approved_ready_to_publish`, `published`, and `reindexed` into one generic success label.
- Failure and fallback reasons must use bounded enums rendered as human-readable copy, not raw inspect output.
- Shell and blocked states are first-class states, not flash-only messages.
- Status truth comes from durable host-owned records; the thread surface only projects that truth.

---

## Status Vocabulary

Use these operator-facing labels exactly:

| Internal concept | Operator label | Surface |
|------------------|----------------|---------|
| idle | No quick fix started | thread card |
| preparing | Preparing quick fix | thread card |
| ready | Review task ready | thread card, review lane |
| shell_created | Draft shell created | thread card, review lane |
| blocked_manual_required | Manual draft required | thread card, review lane |
| approved_ready_to_publish | Approved, awaiting publish | review lane and optional mirrored thread chip |
| published | Published, reindex pending | review lane and optional mirrored thread chip |
| reindexing | Reindexing | review lane and optional mirrored thread chip |
| reindexed | Reindexed | review lane and optional mirrored thread chip |
| retry_needed | Follow-through needs attention | review lane and optional mirrored thread chip |

Blocked or shell reason labels must map to calm copy such as:

- `Missing canonical grounding`
- `Citation anchors unavailable`
- `Policy guard blocked automatic suggestion`
- `Manual authoring required`

Do not expose raw reason atoms directly to operators.

---

## Spacing Scale

Declared values (must be multiples of 4):

| Token | Value | Usage |
|-------|-------|-------|
| xs | 4px | Chip interior gaps, inline icon spacing |
| sm | 8px | Tight metadata gaps, stacked label spacing |
| md | 16px | Default card padding units, button gaps, inline callout padding |
| lg | 24px | Rail-card padding, section separation inside the quick-fix card |
| xl | 32px | Major card-to-card gaps, desktop conversation pane spacing |
| 2xl | 48px | Review detail section separation for status/evidence/history blocks |
| 3xl | 64px | Page-level top rhythm only when introducing large section breaks in review views |

Exceptions: primary and secondary actions plus any chip-like interactive row must preserve a minimum `44px` hit area; no other off-scale spacing values are allowed.

---

## Typography

| Role | Size | Weight | Line Height |
|------|------|--------|-------------|
| Body | 16px | 400 | 1.5 |
| Label | 14px | 600 | 1.4 |
| Heading | 20px | 600 | 1.3 |
| Display | 28px | 600 | 1.2 |

Use Atkinson Hyperlegible Next for all roles in this phase. Do not introduce `--cl-font-display` into the operator quick-fix or review surfaces. Use `--cl-font-mono` only for secondary identifiers such as digests or exact timestamps if surfaced for debugging.

---

## Color

| Role | Value | Usage |
|------|-------|-------|
| Dominant (60%) | `#F5F0E6` (`--cl-bg`) | Conversation canvas, evidence-rail background, surrounding operator shell |
| Secondary (30%) | `#FBF7EE` (`--cl-surface`) | Quick-fix card, review detail panels, inline state containers |
| Accent (10%) | `#A94F30` (`--cl-primary`) | Primary CTA, active status marker, focus ring, current-lane emphasis only |
| Destructive | `#B54C36` (`--cl-danger`) | Blocked/manual-required emphasis and destructive confirmations only |

Accent reserved for: the primary quick-fix CTA, the active step in the follow-through status rail, keyboard focus outlines, and linked destination emphasis. Do not use accent for every badge, heading, or neutral border.

Additional semantic colors from existing tokens:

- `#4A6238` (`--cl-success`) for completed publish or reindex success chips
- `#3F6F80` (`--cl-info`) for neutral evidence-layer and in-progress status chips
- `#8B531E` (`--cl-warning`) for shell-created or awaiting-follow-through states

All status meaning must remain legible in text without depending on color alone.

---

## Copywriting Contract

| Element | Copy |
|---------|------|
| Primary CTA | Start KB quick fix |
| Empty state heading | No quick fix started |
| Empty state body | Use conversation evidence to open a KB maintenance task when this thread exposes missing or stale guidance. |
| Error state | Quick fix could not prepare a reviewable suggestion. Open a manual draft and keep the reason visible in the maintenance lane. |
| Destructive confirmation | none: none |

Additional labels locked for this slice:

- Card eyebrow: `KB maintenance`
- Ready summary: `This conversation can seed a reviewable KB update.`
- Shell summary: `A draft shell was created because the maintenance need is real, but canonical grounding is incomplete.`
- Blocked summary: `Automatic suggestion is blocked for this conversation.`
- Manual path CTA: `Open manual draft`
- Shared-lane link: `View maintenance lane`
- Evidence layer trust labels:
  - `Thread context` -> `Conversation signal`
  - `Canonical retrieval` -> `Citation-eligible`
  - `Resolved case assists` -> `Supporting context`
- Follow-through labels:
  - `Review task ready`
  - `Approved, awaiting publish`
  - `Published, reindex pending`
  - `Reindexing`
  - `Reindexed`
  - `Follow-through needs attention`

Copy rules:

- Always state the current truth and the next safe action in the same region.
- Prefer “review task,” “manual draft,” “publish,” and “reindex” over vague words like “process,” “complete,” or “resolved.”
- Do not describe the quick fix as autonomous or imply it can publish on its own.

---

## Visual Rules

- The quick-fix card must visually match the existing operator card pattern: warm surface, defined border, modest radius, and no marketing-style illustrations.
- Evidence layers should read as structured rows, not prose paragraphs. Use chips or compact metadata blocks, but keep counts and trust roles scannable.
- The blocked/shell reason callout must use stronger contrast than neutral metadata but remain calmer than a destructive delete warning.
- The status rail should feel like a workflow breadcrumb, not a progress bar. Prefer stacked labeled states or a vertical lane marker over percentages.
- Keep the conversation timeline visually dominant. The quick-fix card is an adjacent operational control, not the main page hero.
- Avoid bright blues, generic AI purple, robot imagery, or anything that makes the surface feel like a detached AI tool.

---

## Accessibility And Interaction Safety

- Use real buttons for launch actions and real links for route transitions; do not rely on clickable containers.
- Announce status changes through a polite live region when the quick-fix state changes from `preparing` to `ready`, `shell_created`, or `blocked_manual_required`.
- Keep focus stable after launch. If the operator remains on the thread, focus returns to the primary action region or the newly rendered reason callout.
- If navigation to the review lane occurs immediately after successful creation or reuse, land focus on the review detail heading for the selected task.
- Every status chip needs visible text. Icons are optional reinforcement only.
- Ensure contrast meets WCAG AA against `--cl-surface` and `--cl-bg`, especially for warning and muted copy.

---

## Registry Safety

| Registry | Blocks Used | Safety Gate |
|----------|-------------|-------------|
| shadcn official | none | not applicable - Phoenix LiveView stack - 2026-05-22 |
| third-party registries | none | not applicable - 2026-05-22 |

---

## Implementation Notes

- Pre-populated from upstream:
  - Evidence-rail launch point, shared review-lane handoff, hybrid fail-closed model, and bounded operator-visible status came from [`12-CONTEXT.md`](/Users/jon/projects/cairnloop/.planning/phases/12-in-thread-quick-fix-ops-closure/12-CONTEXT.md:1).
  - Milestone safety and fallback requirements came from [`REQUIREMENTS.md`](/Users/jon/projects/cairnloop/.planning/REQUIREMENTS.md:1).
  - Existing review-lane separation and publish/reindex posture came from [`M010-S03-CONTEXT.md`](/Users/jon/projects/cairnloop/.planning/milestones/M010-phases/M010-S03/M010-S03-CONTEXT.md:1).
  - Brand tokens and operator-tone rules came from [`prompts/cairnloop.css`](/Users/jon/projects/cairnloop/prompts/cairnloop.css:1) and [`prompts/cairnloop_brand_book.md`](/Users/jon/projects/cairnloop/prompts/cairnloop_brand_book.md:538).
- Existing surface seams to extend:
  - [`lib/cairnloop/web/conversation_live.ex`](/Users/jon/projects/cairnloop/lib/cairnloop/web/conversation_live.ex:1) for the evidence-rail card and thread-local status projection.
  - [`lib/cairnloop/web/knowledge_base_live/suggestion_review.ex`](/Users/jon/projects/cairnloop/lib/cairnloop/web/knowledge_base_live/suggestion_review.ex:1) for shared-lane detail/status copy.
  - [`lib/cairnloop/web/knowledge_base_live/editor.ex`](/Users/jon/projects/cairnloop/lib/cairnloop/web/knowledge_base_live/editor.ex:1) for manual authoring recovery without bypassing review truth.
- Keep telemetry and audit truth separate. Telemetry may inform future ops surfaces, but this phase’s operator UI should render only durable workflow truth plus bounded reasons.
- Do not preserve the current inline gray placeholder styles as the final visual direction; this phase should align these surfaces to Cairnloop tokens while staying consistent with the existing operator shell.

---

## Checker Sign-Off

- [ ] Dimension 1 Copywriting: PASS
- [ ] Dimension 2 Visuals: PASS
- [ ] Dimension 3 Color: PASS
- [ ] Dimension 4 Typography: PASS
- [ ] Dimension 5 Spacing: PASS
- [ ] Dimension 6 Registry Safety: PASS

**Approval:** pending
