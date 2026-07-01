# Auth & Operator Identity

Cairnloop is host-owned: it embeds **no** authentication and **no** authorization. You mount its
operator dashboard into *your* router, under *your* pipelines, so login, sessions, and access
control stay entirely yours. Cairnloop only asks one thing of you in return — tell it **who the
signed-in operator is** — and it asks for that through a single, deliberately small seam: the
`host_user_id` value in the dashboard's live session.

This guide explains what `host_user_id` is for, the two distinct seams you wire (authorization vs.
identity injection), the one mistake that quietly breaks both, and the copy-paste pattern that does
it correctly.

---

## What `host_user_id` is — and why it is not cosmetic

`host_user_id` is the identity of the **operator currently using the dashboard** — your staff
member, not the customer. Cairnloop renders it into the dashboard live session and uses it for two
things that matter:

1. **Audit attribution.** When an operator takes a governed action (for example, confirming a bulk
   send), Cairnloop records `host_user_id` as the **actor** on the resulting durable event. This is
   the name that shows up in the audit log as "who did this." If every request carries the same
   hardcoded id, your audit trail attributes *everyone's* actions to that one id — which defeats the
   point of having an audit trail.

2. **Tenant-scoped search.** Operator search is scoped by `host_user_id`. When it is blank, the
   dashboard does not guess: scoped search degrades to a calm, explicit "Scoped search is
   unavailable on this surface until the dashboard session provides `host_user_id`" rather than
   silently searching the wrong tenant.

So `host_user_id` is not a display label — it is governance-bearing identity. Getting it right is
the difference between a trustworthy audit log and one that lies.

> #### Fail-closed by design {: .info}
>
> If you do not provide `host_user_id`, Cairnloop does not crash and does not invent one. Scoped
> search is withheld and the actor on governed events is `nil`. The dashboard stays usable, but you
> are leaving real attribution on the table — treat a `nil` operator as a wiring bug to fix, not a
> supported mode.

---

## Two seams, two jobs

Wiring the dashboard for real auth means answering two *different* questions, with two *different*
mechanisms. Conflating them is the root of most integration confusion.

| Question | Mechanism | Where it lives |
| --- | --- | --- |
| **May this request reach the dashboard at all?** (authorization) | your router `pipe_through` pipeline and/or LiveView `on_mount` hooks | the `scope` wrapping `cairnloop_dashboard/2` |
| **Who is the operator on this request?** (identity injection) | the live session `:session` value | the `session:` option you pass to `cairnloop_dashboard/2` |

`cairnloop_dashboard/2` forwards `:session`, `:on_mount`, `:root_layout`, and `:layout` straight
through to `Phoenix.LiveView.Router.live_session/3`, so both seams are standard Phoenix — there is
no Cairnloop-specific auth API to learn.

### Seam 1 — authorization: who may enter

Gate access with your own pipeline and, optionally, an `on_mount` hook. Cairnloop does not call
these for you; you compose them:

```elixir
scope "/support" do
  pipe_through [:browser, :require_admin]

  Cairnloop.Router.cairnloop_dashboard "/",
    on_mount: [{MyAppWeb.UserAuth, :ensure_admin}],
    session: {MyAppWeb.UserAuth, :cairnloop_session, []}
end
```

`pipe_through` rejects unauthenticated requests at the plug layer; `on_mount` re-checks on the
LiveView connect (live navigation does not re-run plugs, so an `on_mount` hook is how you keep an
authorization invariant across in-dashboard navigation). Neither of these sets `host_user_id` — that
is seam 2's job.

### Seam 2 — identity injection: who the operator is

This is the seam adopters most often get wrong, so it gets its own section below.

---

## The static-map trap

Almost every quickstart — including Cairnloop's own example app — shows the dashboard mounted like
this:

```elixir
# Demo only. Do NOT ship this.
Cairnloop.Router.cairnloop_dashboard "/support",
  session: %{"host_user_id" => "demo_operator"}
```

That works in a demo because there is only ever one operator. But a literal map passed to
`:session` is evaluated **once, when your router module compiles**; static session maps are demo-only traps because they are frozen at build time and identical for every request and every operator forever.
There is no `conn` in scope, so there is no way for a literal map to carry *the operator who is
actually signed in right now.*

Copy that line into a real app and you ship a dashboard where every staff member is `"demo_operator"`:
the audit log attributes everyone's actions to one fictional id, and scoped search is scoped to a
tenant that does not exist. It compiles, it runs, it looks fine in a screenshot — which is exactly
why this is the trap. **Nothing fails loudly.**

---

## The fix: inject identity per request with an MFA

`Phoenix.LiveView.Router.live_session/3` accepts `:session` as **either** a static map **or** an
`{Module, function, args}` tuple. The tuple form is the one you want for real auth: Phoenix invokes
it **once per HTTP request** that establishes the live session, passing the current `Plug.Conn` as
the first argument (`apply(Module, function, [conn | args])`). Your function reads the authenticated
operator off the `conn` and returns the session map:

```elixir
defmodule MyAppWeb.UserAuth do
  # ... your existing fetch_current_user/2 plug, on_mount hooks, etc. ...

  @doc """
  Builds the Cairnloop dashboard live session for the current request.

  Wired as `session: {MyAppWeb.UserAuth, :cairnloop_session, []}` on
  `cairnloop_dashboard/2`. Runs per request with the live `conn`, so it can
  read the authenticated operator — something a static `%{...}` map cannot do.
  """
  def cairnloop_session(conn) do
    %{"host_user_id" => to_string(conn.assigns.current_user.id)}
  end
end
```

Then wire it in your router:

```elixir
scope "/support" do
  pipe_through [:browser, :require_admin]

  Cairnloop.Router.cairnloop_dashboard "/",
    on_mount: [{MyAppWeb.UserAuth, :ensure_admin}],
    session: {MyAppWeb.UserAuth, :cairnloop_session, []}
end
```

A few details worth knowing:

- **Stringify the id.** Live session values are serialized and verified across the websocket
  connect; keep them to JSON-friendly primitives. `host_user_id` is treated as an opaque string
  everywhere in Cairnloop, so `to_string/1` your integer or UUID ids.
- **`current_user` must already be assigned.** `cairnloop_session/1` reads `conn.assigns`, so your
  authentication plug (the one that assigns `current_user`) must run in the `pipe_through` pipeline
  *before* the live session is built. If it might be missing, default deliberately rather than
  letting it raise — see below.
- **The args list is for extra arguments**, appended after `conn`. `[]` is the common case. Use it
  if you want one shared function parameterized per mount, e.g.
  `{MyAppWeb.UserAuth, :cairnloop_session, [:support_desk]}` → `cairnloop_session(conn, :support_desk)`.

### Defaulting safely when there may be no operator

If a route can be reached without an authenticated operator (you generally should not allow this for
the dashboard, but defensive code is cheap), decide explicitly instead of crashing inside the MFA:

```elixir
def cairnloop_session(conn) do
  case conn.assigns[:current_user] do
    nil -> %{}                                   # no operator → fail closed (scoped search off, actor nil)
    user -> %{"host_user_id" => to_string(user.id)}
  end
end
```

Returning `%{}` leaves `host_user_id` unset, which Cairnloop already handles gracefully (see
*Fail-closed by design* above). Raising inside the MFA, by contrast, takes down the request.

---

## Mounting more than one dashboard

If you mount the dashboard twice in one router (say, an internal desk and a partner desk with
different auth), give each its own `:live_session_name` so the generated `live_session` names do not
collide, and inject a different operator/tenant scope per mount:

```elixir
scope "/internal" do
  pipe_through [:browser, :require_staff]
  Cairnloop.Router.cairnloop_dashboard "/support",
    live_session_name: :cairnloop_internal,
    session: {MyAppWeb.UserAuth, :cairnloop_session, [:internal]}
end

scope "/partner" do
  pipe_through [:browser, :require_partner]
  Cairnloop.Router.cairnloop_dashboard "/support",
    live_session_name: :cairnloop_partner,
    session: {MyAppWeb.UserAuth, :cairnloop_session, [:partner]}
end
```

---

## Checklist

- [ ] An authentication plug assigns the current operator **before** the dashboard's live session is
      built (in the `pipe_through` pipeline).
- [ ] Access is gated with `pipe_through` and/or an `on_mount` authorization hook.
- [ ] `:session` is an **MFA tuple**, not a static map — so `host_user_id` is the *real* signed-in
      operator, per request.
- [ ] The MFA returns JSON-friendly primitives (stringified ids).
- [ ] The no-operator branch is handled deliberately (return `%{}`, do not raise).
- [ ] You verified the audit log attributes actions to the actual operator, not a placeholder.

See the worked example in [`examples/cairnloop_example`](https://github.com/szTheory/cairnloop/tree/main/examples/cairnloop_example),
whose `CairnloopExampleWeb.OperatorAuth` demonstrates exactly this MFA seam.
