defmodule Atex.DID do
  @re ~r/^did:[a-z]+:[a-zA-Z0-9._:%-]*[a-zA-Z0-9._-]$/
  @blessed_re ~r/^did:(?:plc|web):[a-zA-Z0-9._:%-]*[a-zA-Z0-9._-]$/

  @spec re() :: Regex.t()
  def re, do: @re

  @spec match?(String.t()) :: boolean()
  def match?(value), do: Regex.match?(@re, value)

  @spec blessed_re() :: Regex.t()
  def blessed_re, do: @blessed_re

  @spec match_blessed?(String.t()) :: boolean()
  def match_blessed?(value), do: Regex.match?(@blessed_re, value)
end
