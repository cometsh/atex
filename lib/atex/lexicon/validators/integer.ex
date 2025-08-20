defmodule Atex.Lexicon.Validators.Integer do
  @type option() ::
          {:minimum, integer()}
          | {:maximum, integer()}

  @option_keys [:minimum, :maximum]

  @spec validate(term(), list(option())) :: Peri.validation_result()
  def validate(value, options) when is_integer(value) do
    options
    |> Keyword.validate!(
      minimum: nil,
      maximum: nil
    )
    |> Stream.map(&validate_option(value, &1))
    |> Enum.find(:ok, fn x -> x != :ok end)
  end

  def validate(value, _options),
    do:
      {:error, "expected type of `integer`, received #{value}",
       [expected: :integer, actual: value]}

  @spec validate_option(integer(), option()) :: Peri.validation_result()
  defp validate_option(value, option)

  defp validate_option(_value, {option, nil}) when option in @option_keys, do: :ok

  defp validate_option(value, {:minimum, expected}) when value >= expected, do: :ok

  defp validate_option(value, {:minimum, expected}) when value < expected,
    do: {:error, "", [value: expected]}

  defp validate_option(value, {:maximum, expected}) when value <= expected, do: :ok

  defp validate_option(value, {:maximum, expected}) when value > expected,
    do: {:error, "", [value: expected]}
end
