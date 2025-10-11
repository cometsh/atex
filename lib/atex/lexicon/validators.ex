defmodule Atex.Lexicon.Validators do
  alias Atex.Lexicon.Validators

  @type blob_option() :: {:accept, list(String.t())} | {:max_size, pos_integer()}

  @type blob() ::
          %{
            "$type": String.t(),
            ref: %{"$link": String.t()},
            mimeType: String.t(),
            size: integer()
          }
          | %{
              cid: String.t(),
              mimeType: String.t()
            }

  @type cid_link() :: %{"$link": String.t()}

  @type bytes() :: %{"$bytes": binary()}

  @spec string(list(Validators.String.option())) :: Peri.custom_def()
  def string(options \\ []), do: {:custom, {Validators.String, :validate, [options]}}

  @spec integer(list(Validators.Integer.option())) :: Peri.custom_def()
  def integer(options \\ []), do: {:custom, {Validators.Integer, :validate, [options]}}

  @spec array(Peri.schema_def(), list(Validators.Array.option())) :: Peri.custom_def()
  def array(inner_type, options \\ []) do
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
          cid: {:required, :string},
          mimeType: mime_type
        }
      }
    }
  end

  @spec bytes(list(Validators.Bytes.option())) :: Peri.schema()
  def bytes(options \\ []) do
    options = Keyword.validate!(options, min_length: nil, max_length: nil)

    %{
      "$bytes":
        {:required,
         {{:custom, {Validators.Bytes, :validate, [options]}}, {:transform, &Base.decode64!/1}}}
    }
  end

  # TODO: see what atcute validators expect
  # TODO: cid validation?
  def cid_link() do
    %{
      "$link": {:required, :string}
    }
  end

  @spec lazy_ref(module(), atom()) :: Peri.schema()
  def lazy_ref(module, schema_name) do
    {:custom, {module, schema_name, []}}
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
