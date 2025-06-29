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

  def validate_map(value, schema, extra_keys_schema) when is_map(value) and is_map(schema) do
    extra_keys =
      Enum.reduce(Map.keys(schema), MapSet.new(Map.keys(value)), fn key, acc ->
        acc |> MapSet.delete(key) |> MapSet.delete(to_string(key))
      end)

    extra_data =
      value
      |> Enum.filter(fn {key, _} -> MapSet.member?(extra_keys, key) end)
      |> Map.new()

    with {:ok, schema_data} <- Peri.validate(schema, value),
         {:ok, extra_data} <- Peri.validate(extra_keys_schema, extra_data) do
      {:ok, Map.merge(schema_data, extra_data)}
    else
      {:error, %Peri.Error{} = err} -> {:error, [err]}
      e -> e
    end
  end

  def validate_map(value, _schema, _extra_keys_schema),
    do: {:error, "must be a map", [value: value]}
end
