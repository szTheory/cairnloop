# M000: Cairnloop Foundation & Core Ingress Loop

## Goal
Establish the Ecto-native foundation, the Igniter installation pipeline, and the fundamental SupportOS loop. 

## Vertical Slices

### Slice 1: Ecto Foundation & Igniter Installer
* **Objective**: Define core schemas and `mix cairnloop.install`.
* **Details**: Append-only `Message` schema, `Conversation` schema, Igniter recipe for migrations.

### Slice 2: Embedded Operator LiveView Dashboard
* **Objective**: Build the initial LiveView inbox interface.
* **Details**: Router macro (`cairnloop_dashboard`), inbox listing, conversation detail view, reply functionality via `Ecto.Multi`.

### Slice 3: Host Context Provider
* **Objective**: Establish the extensibility contract for host context.
* **Details**: Define `SupportOS.ContextProvider` behaviour, display context in the dashboard.

### Slice 4: Resolution Telemetry & Growth Signal (CLG Hook)
* **Objective**: Lay the groundwork for "Customer Voice Activation".
* **Details**: Define `SupportOS.Notifier` behaviour. Emit telemetry upon conversation resolution with sentiment/intent metadata so the host app can trigger growth loops (App Store reviews, referrals).