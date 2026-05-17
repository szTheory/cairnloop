defmodule Cairnloop.Embedder do
  @moduledoc """
  Behaviour for generating vector embeddings from text chunks.
  """

  @callback generate_embeddings(chunks :: [String.t()], opts :: keyword()) ::
              {:ok, [[float()]]} | {:error, term()}
end
