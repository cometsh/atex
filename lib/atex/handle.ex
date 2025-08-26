defmodule Atex.Handle do
  @re ~r/^(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$/

  @spec re() :: Regex.t()
  def re, do: @re

  @spec match?(String.t()) :: boolean()
  def match?(value), do: Regex.match?(@re, value)
end
