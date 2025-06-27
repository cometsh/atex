defmodule Atex.Lexicon.Validators do
  alias Atex.Lexicon.Validators

  @type blob_option() :: {:accept, list(String.t())} | {:max_size, integer()}

  @type blob_t() ::
          %{
            "$type": String.t(),
            req: %{"$link": String.t()},
            mimeType: String.t(),
            size: integer()
          }
          | %{}

  @spec string(list(Validators.String.option())) :: Peri.custom_def()
  def string(options \\ []), do: {:custom, {Validators.String, :validate, [options]}}

  @spec integer(list(Validators.Integer.option())) :: Peri.custom_def()
  def integer(options \\ []), do: {:custom, {Validators.Integer, :validate, [options]}}

  @spec array(Peri.schema_def(), list(Validators.Array.option())) :: Peri.custom_def()
  def array(inner_type, options \\ []) do
    {:ok, ^inner_type} = Peri.validate_schema(inner_type)
    {:custom, {Validators.Array, :validate, [inner_type, options]}}
  end

  @spec blob(list(blob_option())) :: Peri.schema_def()
  def blob(options \\ []) do
    options = Keyword.validate!(options, accept: nil, max_size: nil)
    accept = Keyword.get(options, :accept)
    max_size = Keyword.get(options, :max_size)

    mime_type =
      {:required,
       if(accept,
         do: {:string, {:regex, strings_to_re(accept)}},
         else: {:string, {:regex, ~r"^.+/.+$"}}
       )}

    {
      :either,
      {
        # Newer blobs
        %{
          "$type": {:required, {:literal, "blob"}},
          ref: {:required, %{"$link": {:required, :string}}},
          mimeType: mime_type,
          size: {:required, if(max_size != nil, do: {:integer, {:lte, max_size}}, else: :integer)}
        },
        # Old deprecated blobs
        %{
          cid: {:reqiured, :string},
          mimeType: mime_type
        }
      }
    }
  end

  @spec boolean_validate(boolean(), String.t(), keyword() | map()) ::
          Peri.validation_result()
  def boolean_validate(success?, error_message, context \\ []) do
    if success? do
      :ok
    else
      {:error, error_message, context}
    end
  end

  @spec strings_to_re(list(String.t())) :: Regex.t()
  defp strings_to_re(strings) do
    strings
    |> Enum.map(&String.replace(&1, "*", ".+"))
    |> Enum.join("|")
    |> then(&~r/^(#{&1})$/)
  end
end
