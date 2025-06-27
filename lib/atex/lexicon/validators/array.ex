defmodule Atex.Lexicon.Validators.Array do
  @type option() :: {:min_length, non_neg_integer()} | {:max_length, non_neg_integer()}

  @option_keys [:min_length, :max_length]

  # Needs type input
  @spec validate(Peri.schema_def(), term(), list(option())) :: Peri.validation_result()
  def validate(inner_type, value, options) when is_list(value) do
    # TODO: validate inner_type with Peri to make sure it's correct?

    options
    |> Keyword.validate!(min_length: nil, max_length: nil)
    |> Stream.map(&validate_option(value, &1))
    |> Enum.find(:ok, fn x -> x != :ok end)
    |> case do
      :ok ->
        value
        |> Stream.map(&Peri.validate(inner_type, &1))
        |> Enum.find({:ok, nil}, fn
          {:ok, _} -> false
          {:error, _} -> true
        end)
        |> case do
          {:ok, _} -> :ok
          e -> e
        end

      e ->
        e
    end
  end

  def validate(_inner_type, value, _options),
    do: {:error, "expected type of `array`, received #{value}", [expected: :array, actual: value]}

  @spec validate_option(list(), option()) :: Peri.validation_result()
  defp validate_option(value, option)

  defp validate_option(_value, {option, nil}) when option in @option_keys, do: :ok

  defp validate_option(value, {:min_length, expected}) when length(value) >= expected,
    do: :ok

  defp validate_option(value, {:min_length, expected}) when length(value) < expected,
    do: {:error, "should have a minimum length of #{expected}", [length: expected]}

  defp validate_option(value, {:max_length, expected}) when length(value) <= expected,
    do: :ok

  defp validate_option(value, {:max_length, expected}) when length(value) > expected,
    do: {:error, "should have a maximum length of #{expected}", [length: expected]}
end
