defmodule Atex.Lexicon.Validators.Bytes do
  @type option() :: {:min_length, pos_integer()} | {:max_length, pos_integer()}

  @option_keys [:min_length, :max_length]

  @spec validate(term(), list(option())) :: Peri.validation_result()
  def validate(value, options) when is_binary(value) do
    case Base.decode64(value, padding: false) do
      {:ok, bytes} ->
        options
        |> Keyword.validate!(min_length: nil, max_length: nil)
        |> Stream.map(&validate_option(bytes, &1))
        |> Enum.find(:ok, fn x -> x !== :ok end)

      :error ->
        {:error, "expected valid base64 encoded bytes", []}
    end
  end

  def validate(value, _options),
    do:
      {:error, "expected valid base64 encoded bytes, received #{value}",
       [expected: :bytes, actual: value]}

  defp validate_option(_value, {option, nil}) when option in @option_keys, do: :ok

  defp validate_option(value, {:min_length, expected}) when byte_size(value) < expected,
    do: {:error, "should have a minimum byte length of #{expected}", [length: expected]}

  defp validate_option(value, {:max_length, expected}) when byte_size(value) <= expected,
    do: :ok
end
