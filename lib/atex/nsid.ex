defmodule Atex.NSID do
  @re ~r/^[a-zA-Z](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+(?:\\.[a-zA-Z](?:[a-zA-Z0-9]{0,62})?)$/

  @spec re() :: Regex.t()
  def re, do: @re

  @spec match?(String.t()) :: boolean()
  def match?(value), do: Regex.match?(@re, value)

  # TODO: methods for fetching the authority and name from a nsid.
  # maybe stuff for fetching the repo that belongs to an authority
end
