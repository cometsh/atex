defmodule Atex.Lexicon.Validators.Integer do
  alias Atex.Lexicon.Validators

  @type option() ::
          {:minimum, integer()}
          | {:maximum, integer()}
          | {:enum, list(integer())}
          | {:const, integer()}

  @option_keys [:minimum, :maximum, :enum, :const]

  @spec validate(term(), list(option())) :: Peri.validation_result()
  def validate(value, options) when is_integer(value) do
    options
    |> Keyword.validate!(
      minimum: nil,
      maximum: nil,
      enum: nil,
      const: nil
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

  defp validate_option(value, {:enum, values}),
    do:
      Validators.boolean_validate(value in values, "should be one of the expected values",
        enum: values
      )

  defp validate_option(value, {:const, expected}) when value == expected, do: :ok

  defp validate_option(value, {:const, expected}),
    do: {:error, "should match constant value", [actual: value, expected: expected]}
end
