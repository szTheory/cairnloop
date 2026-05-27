---
status: partial
phase: 28-customer-chat-wired-to-real-ingress
source: [28-VERIFICATION.md]
started: 2026-05-27T18:25:00Z
updated: 2026-05-27T18:25:00Z
---

## Current Test

[awaiting human testing]

## Tests

### 1. Two-tab round trip (customer → operator)
expected: Open /chat as customer, open /conversations as operator. Type message in customer tab → message appears in operator ConversationLive in real time (no page refresh). Reply from operator tab → reply appears in customer ChatLive in real time.
result: [pending]

### 2. Multi-message-stack manual UAT
expected: Send multiple messages back and forth between customer and operator tabs. All messages stack in correct order in both UIs. No duplicate messages, no missed messages.
result: [pending]

### 3. No mock bot-reply copy visible
expected: After customer sends a message, confirm no "bot reply" or mock response copy appears in the ChatLive UI. Only real operator replies (via PubSub from reply_to_conversation/4) should appear.
result: [pending]

### 4. Operator inbox auto-refresh on new customer join
expected: When customer opens /chat (creating a new conversation), the operator InboxLive at /conversations automatically updates to show the new conversation (D-09/D-10 PubSub path). No page refresh required.
result: [pending]

## Summary

total: 4
passed: 0
issues: 0
pending: 4
skipped: 0
blocked: 0

## Gaps
