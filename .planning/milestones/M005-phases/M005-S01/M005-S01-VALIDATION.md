# M005-S01 Validation: Durable Auditing

This document outlines the manual Quality Assurance (QA) and validation steps required to verify that the Phase Goal (Durable Auditing via Ecto.Multi) has been successfully achieved.

## Prerequisites

1. A host application integrating the updated Cairnloop library.
2. A custom Auditor module defined in the host application that interacts with a `Threadline` (or similar audit log table) via `Ecto.Multi`.

Example test auditor in host app:
```elixir
defmodule MyApp.ThreadlineAuditor do
  @behaviour Cairnloop.Auditor

  def audit(multi, action, actor, metadata) do
    Ecto.Multi.insert(multi, {:audit, action}, %MyApp.Threadline{
      action: to_string(action),
      actor: actor,
      metadata: metadata
    })
  end
end
```

## Validation Steps

### 1. Configure the Custom Auditor
- In the host application's configuration, set the auditor:
  ```elixir
  config :cairnloop, auditor: MyApp.ThreadlineAuditor
  ```

### 2. Verify Automation Flow Auditing
- **Action:** Trigger the `Cairnloop.Automation.approve_draft/2` (or discard/mark edited) function, passing an actor in the options (e.g., `opts = [actor: "user_123"]`).
- **Expected Outcome:** The draft is approved successfully.
- **Verification:** Query the `Threadline` table in the database and verify that a new record exists for the `approve_draft` action, with the correct `actor` and `metadata` (containing the draft ID). Both the draft update and the Threadline insert must have occurred within the same database transaction.

### 3. Verify Chat Flow Auditing
- **Action:** Trigger `Cairnloop.Chat.reply_to_conversation/4` and `Cairnloop.Chat.resolve_conversation/3` with the appropriate actor options.
- **Expected Outcome:** The chat actions complete successfully.
- **Verification:** Query the `Threadline` table and verify records exist for the reply and resolve actions with the correct context.

### 4. Verify Transactional Integrity (Rollback)
- **Action:** Temporarily modify the host application's `MyApp.ThreadlineAuditor` to purposefully cause an error during the `Ecto.Multi` execution (e.g., return an invalid changeset for the Threadline insert), OR force a failure in the Cairnloop core action after the auditor is injected.
- **Expected Outcome:** The entire `Ecto.Multi` transaction fails.
- **Verification:** Ensure that neither the core action (e.g., draft approval) nor the audit record (Threadline) is persisted to the database. This proves that the auditor is successfully participating in the core Ecto.Multi transaction and ensuring atomic durability.
