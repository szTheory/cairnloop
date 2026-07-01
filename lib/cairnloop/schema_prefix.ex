defmodule Cairnloop.SchemaPrefix do
  @moduledoc """
  Internal helpers for Cairnloop's Postgres schema-prefix contract.

  New installs default Cairnloop support-domain tables to the `cairnloop` Postgres schema. Existing
  public-schema installs may explicitly set `config :cairnloop, :schema_prefix, "public"` or the
  legacy `nil` compatibility value while they migrate. Oban remains host-owned and is not covered
  by this prefix.
  """

  @default "cairnloop"
  @identifier ~r/\A[A-Za-z_][A-Za-z0-9_]*\z/

  @doc false
  def default, do: @default

  @doc false
  def configured(opts \\ []) do
    opts
    |> Keyword.get(:schema_prefix, Application.get_env(:cairnloop, :schema_prefix, @default))
    |> normalize!()
  end

  @doc false
  def repo_opts(opts \\ []) do
    prefix = configured(opts)
    opts = Keyword.delete(opts, :schema_prefix)

    case prefix do
      nil -> opts
      prefix -> Keyword.put_new(opts, :prefix, prefix)
    end
  end

  @doc false
  def quoted_table(table, opts \\ []) when is_binary(table) do
    table = quote_identifier!(table)

    case configured(opts) do
      nil -> table
      prefix -> quote_identifier!(prefix) <> "." <> table
    end
  end

  @doc false
  def quote_identifier!(identifier) when is_binary(identifier) do
    if Regex.match?(@identifier, identifier) do
      ~s("#{identifier}")
    else
      raise ArgumentError,
            "invalid Cairnloop schema/table identifier #{inspect(identifier)}; " <>
              "expected a single SQL identifier"
    end
  end

  @doc false
  def normalize!(nil), do: nil
  def normalize!(""), do: nil

  def normalize!(prefix) when is_binary(prefix) do
    if Regex.match?(@identifier, prefix) do
      prefix
    else
      raise ArgumentError,
            "invalid :cairnloop, :schema_prefix #{inspect(prefix)}; " <>
              "expected nil or a single SQL identifier"
    end
  end

  def normalize!(prefix) do
    raise ArgumentError,
          "invalid :cairnloop, :schema_prefix #{inspect(prefix)}; " <>
            "expected nil or a single SQL identifier"
  end
end
