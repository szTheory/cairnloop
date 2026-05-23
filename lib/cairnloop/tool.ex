defmodule Cairnloop.Tool do
  @moduledoc """
  Governed-tool behaviour and compile-time validating `__using__` macro.

  Host developers declare a governed tool with:

      use Cairnloop.Tool,
        risk_tier: :read_only,
        title: "Lookup Order",
        description: "Retrieve an order by ID."

  The macro validates `risk_tier` and `approval_mode` enum values at **compile time**
  (raises `CompileError` on bad values), derives a fail-closed `approval_mode` from
  `risk_tier` when omitted, and generates a `__tool_spec__/0` returning a frozen
  `%Cairnloop.Tool.Spec{}` pure data struct.

  A tool that declares no policy is denied by default — `authorize/2` returns
  `{:error, :no_policy_defined}` unless overridden.

  ## Callbacks

  Required (host must implement):
  - `run/3` — executes the tool; NOT called in Phase 13
  - `changeset/2` — validates typed input via Ecto embedded schema (D-04)
  - `scope/0` — returns list of required scope atoms

  Optional:
  - `authorize/2` — dynamic policy callback; defaults to `{:error, :no_policy_defined}` (deny-by-default, D-16)
  - `custom_ui/0` — custom LiveView UI module; defaults to `nil`
  - `preview/1` — human-readable consequence summary; no default (Phase 14 seam)
  """

  @type actor_id :: String.t()
  @type context :: map()

  @doc """
  Executes the tool logic with the populated struct.
  Returns `{:ok, result}` or `{:error, reason}`.

  NOT called in Phase 13 — execution is deferred to Phase 16.
  """
  @callback run(tool :: struct(), actor_id(), context()) :: {:ok, any()} | {:error, any()}

  @doc """
  Returns an Ecto changeset for the tool's inputs.
  This is the typed-input seam (D-04). Host must implement; no default is injected.
  """
  @callback changeset(tool :: struct(), attrs :: map()) :: Ecto.Changeset.t()

  @doc """
  Returns the list of scope atoms this tool requires to be present in the actor context.
  Used by the registry visibility filter and the Governance validation pipeline.
  """
  @callback scope() :: [atom()]

  @doc """
  Dynamic policy callback. Returns `:ok` to permit or `{:error, reason}` to deny.
  Default implementation returns `{:error, :no_policy_defined}` (deny-by-default, D-16).
  """
  @callback authorize(actor_id(), context()) :: :ok | {:error, reason :: atom()}

  @doc """
  Optional callback to provide a custom UI module (e.g. a LiveView module)
  that should be rendered instead of the auto-generated form.
  """
  @callback custom_ui() :: module() | nil

  @doc """
  Optional callback returning a human-readable consequence summary string.
  No default implementation — Phase 14 seam.
  """
  @callback preview(tool :: struct()) :: String.t()

  @optional_callbacks [preview: 1, custom_ui: 0]

  @valid_risk_tiers [:read_only, :low_write, :high_write, :destructive]
  @valid_approval_modes [:auto, :requires_approval, :always_block]

  defmacro __using__(opts) do
    risk_tier = Keyword.get(opts, :risk_tier)
    approval_mode = Keyword.get(opts, :approval_mode)

    # Validate AT COMPILE TIME — inside defmacro body, BEFORE quote do (Pitfall 5 / D-02)
    if risk_tier && risk_tier not in @valid_risk_tiers do
      raise CompileError,
        description:
          "invalid risk_tier #{inspect(risk_tier)}, expected one of #{inspect(@valid_risk_tiers)}"
    end

    if approval_mode && approval_mode not in @valid_approval_modes do
      raise CompileError,
        description:
          "invalid approval_mode #{inspect(approval_mode)}, expected one of #{inspect(@valid_approval_modes)}"
    end

    derived_approval_mode = approval_mode || Cairnloop.Tool.derive_approval_mode(risk_tier)

    quote do
      use Ecto.Schema
      import Ecto.Changeset
      @behaviour Cairnloop.Tool

      @__tool_spec__ %Cairnloop.Tool.Spec{
        risk_tier: unquote(risk_tier),
        approval_mode: unquote(derived_approval_mode),
        idempotency: unquote(Keyword.get(opts, :idempotency)),
        result_states: unquote(Keyword.get(opts, :result_states, [])),
        title: unquote(Keyword.get(opts, :title)),
        description: unquote(Keyword.get(opts, :description))
      }

      def __tool_spec__, do: @__tool_spec__

      @impl Cairnloop.Tool
      def authorize(_actor_id, _context), do: {:error, :no_policy_defined}

      @impl Cairnloop.Tool
      def custom_ui, do: nil

      defoverridable authorize: 2, custom_ui: 0
    end
  end

  @doc """
  Derives the fail-closed `approval_mode` from a `risk_tier` value (D-11).

  Called at macro-expansion time (not runtime) so this is a plain `def`, not a macro.

      read_only    -> :auto
      low_write    -> :requires_approval
      high_write   -> :requires_approval
      destructive  -> :always_block
      unknown/nil  -> :always_block  (fail-closed default)
  """
  def derive_approval_mode(:read_only), do: :auto
  def derive_approval_mode(:low_write), do: :requires_approval
  def derive_approval_mode(:high_write), do: :requires_approval
  def derive_approval_mode(:destructive), do: :always_block
  def derive_approval_mode(_), do: :always_block
end
