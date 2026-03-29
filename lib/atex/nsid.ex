defmodule Atex.NSID do
  @re ~r/^[a-zA-Z](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+(?:\.[a-zA-Z](?:[a-zA-Z0-9]{0,62})?)$/
  # TODO: regex with support for fragment

  @spec re() :: Regex.t()
  def re, do: @re

  @spec match?(String.t()) :: boolean()
  def match?(value), do: Regex.match?(@re, value)

  @spec to_atom(String.t()) :: atom()
  def to_atom(nsid, fully_qualify \\ true) do
    nsid
    |> String.split(".")
    |> Enum.map(&Recase.to_pascal/1)
    |> then(fn parts ->
      if fully_qualify do
        ["Elixir" | parts]
      else
        parts
      end
    end)
    |> Enum.join(".")
    |> String.to_atom()
  end

  @spec to_atom_with_fragment(String.t()) :: {atom(), atom()}
  def to_atom_with_fragment(nsid) do
    if !String.contains?(nsid, "#") do
      {to_atom(nsid), :main}
    else
      [nsid, fragment] = String.split(nsid, "#")
      {to_atom(nsid), String.to_atom(fragment)}
    end
  end

  @spec expand_possible_fragment_shorthand(String.t(), String.t()) :: String.t()
  def expand_possible_fragment_shorthand(main_nsid, possible_fragment) do
    if String.starts_with?(possible_fragment, "#") do
      main_nsid <> possible_fragment
    else
      possible_fragment
    end
  end

  @spec canonical_name(String.t(), String.t()) :: String.t()
  def canonical_name(nsid, fragment) do
    if fragment == "main" do
      nsid
    else
      "#{nsid}##{fragment}"
    end
  end

  @doc """
  Returns the DNS authority domain for a given NSID, as used for lexicon
  resolution via DNS TXT records.

  The authority domain is derived by stripping the final name segment from the
  NSID, reversing the remaining authority parts, and prepending `_lexicon.`.

  Returns `{:error, :invalid_nsid}` if the input is not a valid NSID.

  ## Examples

      iex> Atex.NSID.authority_domain("app.bsky.feed.post")
      {:ok, "_lexicon.feed.bsky.app"}

      iex> Atex.NSID.authority_domain("edu.university.dept.lab.blogging.getBlogPost")
      {:ok, "_lexicon.blogging.lab.dept.university.edu"}

      iex> Atex.NSID.authority_domain("invalid")
      {:error, :invalid_nsid}
  """
  @spec authority_domain(String.t()) :: {:ok, String.t()} | {:error, :invalid_nsid}
  def authority_domain(nsid) do
    if match?(nsid) do
      authority =
        nsid
        |> String.split(".")
        |> Enum.drop(-1)
        |> Enum.reverse()
        |> Enum.join(".")

      {:ok, "_lexicon.#{authority}"}
    else
      {:error, :invalid_nsid}
    end
  end
end
