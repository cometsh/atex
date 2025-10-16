defmodule Atex.Lexicon.Validators.String do
  alias Atex.Lexicon.Validators

  @type option() ::
          {:format, String.t()}
          | {:min_length, non_neg_integer()}
          | {:max_length, non_neg_integer()}
          | {:min_graphemes, non_neg_integer()}
          | {:max_graphemes, non_neg_integer()}

  @option_keys [
    :format,
    :min_length,
    :max_length,
    :min_graphemes,
    :max_graphemes
  ]

  @record_key_re ~r"^[a-zA-Z0-9.-_:~]$"

  @spec validate(term(), list(option())) :: Peri.validation_result()
  def validate(value, options) when is_binary(value) do
    options
    |> Keyword.validate!(
      format: nil,
      min_length: nil,
      max_length: nil,
      min_graphemes: nil,
      max_graphemes: nil
    )
    # Stream so we early exit at the first error.
    |> Stream.map(&validate_option(value, &1))
    |> Enum.find(:ok, fn x -> x != :ok end)
  end

  def validate(value, _options),
    do:
      {:error, "expected type of `string`, received #{value}", [expected: :string, actual: value]}

  @spec validate_option(String.t(), option()) :: Peri.validation_result()
  defp validate_option(value, option)

  defp validate_option(_value, {option, nil}) when option in @option_keys, do: :ok

  defp validate_option(value, {:format, "at-identifier"}),
    do:
      Validators.boolean_validate(
        Atex.DID.match?(value) or Atex.Handle.match?(value),
        "should be a valid DID or handle"
      )

  defp validate_option(value, {:format, "at-uri"}),
    do: Validators.boolean_validate(Atex.AtURI.match?(value), "should be a valid at:// URI")

  defp validate_option(value, {:format, "cid"}) do
    # TODO: is there a regex provided by the lexicon docs/somewhere?
    try do
      Multiformats.CID.decode(value)
      :ok
    rescue
      _ -> {:error, "should be a valid CID", []}
    end
  end

  defp validate_option(value, {:format, "datetime"}) do
    # NaiveDateTime is used over DateTime because the result isn't actually
    # being used, so we don't need to include a calendar library just for this.
    case NaiveDateTime.from_iso8601(value) do
      {:ok, _} -> :ok
      {:error, _} -> {:error, "should be a valid datetime", []}
    end
  end

  defp validate_option(value, {:format, "did"}),
    do: Validators.boolean_validate(Atex.DID.match?(value), "should be a valid DID")

  defp validate_option(value, {:format, "handle"}),
    do: Validators.boolean_validate(Atex.Handle.match?(value), "should be a valid handle")

  defp validate_option(value, {:format, "nsid"}),
    do: Validators.boolean_validate(Atex.NSID.match?(value), "should be a valid NSID")

  defp validate_option(value, {:format, "tid"}),
    do: Validators.boolean_validate(Atex.TID.match?(value), "should be a valid TID")

  defp validate_option(value, {:format, "record-key"}),
    do:
      Validators.boolean_validate(
        Regex.match?(@record_key_re, value),
        "should be a valid record key"
      )

  defp validate_option(value, {:format, "uri"}) do
    case URI.new(value) do
      {:ok, _} -> :ok
      {:error, _} -> {:error, "should be a valid URI", []}
    end
  end

  defp validate_option(value, {:format, "language"}) do
    case Cldr.LanguageTag.parse(value) do
      {:ok, _} -> :ok
      {:error, _} -> {:error, "should be a valid BCP 47 language tag", []}
    end
  end

  defp validate_option(value, {:min_length, expected}) when byte_size(value) >= expected,
    do: :ok

  defp validate_option(value, {:min_length, expected}) when byte_size(value) < expected,
    do: {:error, "should have a minimum byte length of #{expected}", [length: expected]}

  defp validate_option(value, {:max_length, expected}) when byte_size(value) <= expected,
    do: :ok

  defp validate_option(value, {:max_length, expected}) when byte_size(value) > expected,
    do: {:error, "should have a maximum byte length of #{expected}", [length: expected]}

  defp validate_option(value, {:min_graphemes, expected}),
    do:
      Validators.boolean_validate(
        String.length(value) >= expected,
        "should have a minimum length of #{expected}",
        length: expected
      )

  defp validate_option(value, {:max_graphemes, expected}),
    do:
      Validators.boolean_validate(
        String.length(value) <= expected,
        "should have a maximum length of #{expected}",
        length: expected
      )
end
