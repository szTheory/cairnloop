defmodule CairnloopExampleWeb.PageController do
  use CairnloopExampleWeb, :controller

  # The demo index frames the Trailmark scenario and hands the visitor a guided, click-around
  # tour of the full JTBD lifecycle. Each tour stop deep-links to a conversation that the seed
  # (priv/repo/seeds.exs) pre-positions in exactly that state, so the demo shows truthful data
  # with no setup clicks. Conversation ids are stable because the seed inserts in a fixed order:
  # cohort demo-01..16 → ids 1..16, then the showcase states demo-17..20 → ids 17..20.
  @tour [
    %{
      n: 1,
      title: "A customer message arrives",
      body:
        "A Trailmark customer asks a question in the in-app chat widget. It lands in the operator inbox as a new conversation in real time.",
      href: "/chat",
      cta: "Open the customer chat"
    },
    %{
      n: 2,
      title: "The inbox sees it",
      body:
        "The operator inbox lists every conversation across its lifecycle — new, awaiting customer, and resolved — with SLA and customer context at a glance.",
      href: "/support",
      cta: "Open the operator inbox"
    },
    %{
      n: 3,
      title: "Work the conversation + search the knowledge base",
      body:
        "Open a conversation to see the full timeline and customer context. Press ⌘K to search the knowledge base and drop a cited, grounded answer into your reply.",
      href: "/support/1",
      cta: "Open a live conversation"
    },
    %{
      n: 4,
      title: "Approve an AI draft",
      body:
        "Cairnloop proposes a grounded reply. The operator reviews it and approves — nothing is sent to a customer without a human in the loop.",
      href: "/support/17",
      cta: "See a pending AI draft"
    },
    %{
      n: 5,
      title: "A governed action waits for approval",
      body:
        "Higher-risk actions become proposals that sit in an approval lane with a full reason trail — safe by default, never auto-executed.",
      href: "/support/18",
      cta: "See an action pending approval"
    },
    %{
      n: 6,
      title: "The approved action executes",
      body:
        "Once approved, the action runs exactly once and the durable record flips to executed — every step captured as an audit event.",
      href: "/support/19",
      cta: "See a completed action"
    },
    %{
      n: 7,
      title: "Resolve the conversation",
      body:
        "When the customer is taken care of, the conversation resolves — carrying its outcome and CSAT signal for later.",
      href: "/support/20",
      cta: "See a resolved conversation"
    },
    %{
      n: 8,
      title: "Follow up with a recovery message",
      body:
        "From a resolved conversation, the operator triggers a durable outbound follow-up. It stays attached to the timeline with its delivery status.",
      href: "/support/20",
      cta: "See an outbound follow-up"
    },
    %{
      n: 9,
      title: "Recover a whole cohort at once",
      body:
        "Back in the inbox, multi-select resolved conversations and send one recovery follow-up to all of them under a single durable envelope.",
      href: "/support",
      cta: "Try bulk recovery in the inbox"
    }
  ]

  @surfaces [
    %{
      label: "Knowledge base",
      body: "Published articles & revisions",
      href: "/support/knowledge-base"
    },
    %{
      label: "Knowledge gaps",
      body: "Unanswered customer patterns",
      href: "/support/knowledge-base/gaps"
    },
    %{
      label: "Article suggestions",
      body: "AI-proposed KB improvements",
      href: "/support/knowledge-base/suggestions"
    },
    %{label: "Audit log", body: "Every governed-action event", href: "/support/audit-log"},
    %{label: "Settings", body: "Tokens, health, integrations", href: "/support/settings"},
    %{label: "Health probe", body: "Liveness JSON for infra", href: "/health"}
  ]

  def home(conn, _params) do
    render(conn, :home, tour: @tour, surfaces: @surfaces, page_title: "Cairnloop — live demo")
  end
end
