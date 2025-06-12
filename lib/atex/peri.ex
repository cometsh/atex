defmodule Atex.Peri do
  @moduledoc """
  Custom validators for Peri, for use within atex.
  """

  def uri, do: {:custom, &validate_uri/1}
  def did, do: {:string, {:regex, ~r/^did:[a-z]+:[a-zA-Z0-9._:%-]*[a-zA-Z0-9._-]$/}}

  defp validate_uri(uri) when is_binary(uri) do
    case URI.new(uri) do
      {:ok, _} -> :ok
      {:error, _} -> {:error, "must be a valid URI", [uri: uri]}
    end
  end

  defp validate_uri(uri), do: {:error, "must be a valid URI", [uri: uri]}
end
