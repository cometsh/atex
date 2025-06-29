defmodule Atex.Lexicon do
  @moduledoc """
  Provide `deflexicon` macro for defining a module with types and schemas from an entire lexicon definition.

  Should it also define structs, with functions to convert from input case to snake case?
  """

  alias Atex.Lexicon.Validators

  defmacro __using__(_opts) do
    quote do
      import Atex.Lexicon
      import Atex.Lexicon.Validators
      import Peri
    end
  end

  defmacro deflexicon(lexicon) do
    # Better way to get the real map, without having to eval? (custom function to compose one from quoted?)
    lexicon =
      lexicon
      |> Code.eval_quoted()
      |> elem(0)
      |> then(&Recase.Enumerable.atomize_keys/1)
      |> then(&Atex.Lexicon.Schema.lexicon!/1)

    # TODO: support returning typedefs
    defs =
      lexicon.defs
      |> Enum.flat_map(fn {def_name, def} -> def_to_schema(lexicon.id, def_name, def) end)
      |> Enum.map(fn {schema_key, quoted_schema} ->
        quote do
          defschema unquote(schema_key), unquote(quoted_schema)
        end
      end)

    quote do
      def id, do: unquote(Atex.NSID.to_atom(lexicon.id))

      unquote_splicing(defs)
    end
  end

  # TODO: generate typedefs
  @spec def_to_schema(nsid :: String.t(), def_name :: String.t(), lexicon_def :: map()) ::
          list({key :: atom(), quoted :: term()})

  defp def_to_schema(nsid, def_name, %{type: "record", record: record}) do
    # TODO: record rkey format validator
    def_to_schema(nsid, def_name, record)
  end

  defp def_to_schema(
         nsid,
         def_name,
         %{
           type: "object",
           properties: properties,
           required: required
         } = def
       ) do
    nullable = Map.get(def, :nullable, [])

    properties
    |> Enum.map(fn {key, field} ->
      field_to_schema(field, nsid)
      |> then(
        &if key in nullable, do: quote(do: {:either, {{:literal, nil}, unquote(&1)}}), else: &1
      )
      |> then(&if key in required, do: quote(do: {:required, unquote(&1)}), else: &1)
      |> then(&{key, &1})
    end)
    |> then(&{:%{}, [], &1})
    |> then(&[{atomise(def_name), &1}])
  end

  # TODO: validating errors?
  defp def_to_schema(nsid, _def_name, %{type: "query"} = def) do
    params =
      if def[:parameters] do
        [schema] =
          def_to_schema(nsid, "params", %{
            type: "object",
            required: def.parameters.required,
            nullable: [],
            properties: def.parameters.properties
          })

        schema
      end

    output =
      if def.output && def.output.schema do
        [schema] = def_to_schema(nsid, "output", def.output.schema)
        schema
      end

    [params, output]
    |> Enum.reject(&is_nil/1)
  end

  defp def_to_schema(nsid, _def_name, %{type: "procedure"} = def) do
    # TODO: better keys for these
    params =
      if def[:parameters] do
        [schema] =
          def_to_schema(nsid, "params", %{
            type: "object",
            required: def.parameters.required,
            properties: def.parameters.properties
          })

        schema
      end

    output =
      if def[:output] && def.output.schema do
        [schema] = def_to_schema(nsid, "output", def.output.schema)
        schema
      end

    input =
      if def[:input] && def.input.schema do
        [schema] = def_to_schema(nsid, "output", def.input.schema)
        schema
      end

    [params, output, input]
    |> Enum.reject(&is_nil/1)
  end

  defp def_to_schema(nsid, _def_name, %{type: "subscription"} = def) do
    params =
      if def[:parameters] do
        [schema] =
          def_to_schema(nsid, "params", %{
            type: "object",
            required: def.parameters.required,
            properties: def.parameters.properties
          })

        schema
      end

    message =
      if def[:message] do
        [schema] = def_to_schema(nsid, "message", def.message.schema)
        schema
      end

    [params, message]
    |> Enum.reject(&is_nil/1)
  end

  defp def_to_schema(_nsid, def_name, %{type: "token"}) do
    # TODO: make it a validator that expects the nsid + key.
    [{atomise(def_name), :string}]
  end

  defp def_to_schema(nsid, def_name, %{type: type} = def)
       when type in [
              "blob",
              "array",
              "boolean",
              "integer",
              "string",
              "bytes",
              "cid-link",
              "unknown"
            ] do
    [{atomise(def_name), field_to_schema(def, nsid)}]
  end

  @spec field_to_schema(field_def :: %{type: String.t()}, nsid :: String.t()) :: Peri.schema_def()
  defp field_to_schema(%{type: "string"} = field, _nsid) do
    fixed_schema = const_or_enum(field)

    if fixed_schema do
      maybe_default(fixed_schema, field)
    else
      field
      |> Map.take([
        :format,
        :maxLength,
        :minLength,
        :maxGraphemes,
        :minGraphemes
      ])
      |> Enum.map(fn {k, v} -> {Recase.to_snake(k), v} end)
      |> then(&{:custom, {Validators.String, :validate, [&1]}})
      |> maybe_default(field)
      |> then(&Macro.escape/1)
    end
  end

  defp field_to_schema(%{type: "boolean"} = field, _nsid) do
    (const(field) || :boolean)
    |> maybe_default(field)
    |> then(&Macro.escape/1)
  end

  defp field_to_schema(%{type: "integer"} = field, _nsid) do
    fixed_schema = const_or_enum(field)

    if fixed_schema do
      maybe_default(fixed_schema, field)
    else
      field
      |> Map.take([:maximum, :minimum])
      |> Keyword.new()
      |> then(&{:custom, {Validators.Integer, [&1]}})
      |> maybe_default(field)
    end
    |> then(&Macro.escape/1)
  end

  defp field_to_schema(%{type: "array", items: items} = field, nsid) do
    inner_schema = field_to_schema(items, nsid)

    field
    |> Map.take([:maxLength, :minLength])
    |> Enum.map(fn {k, v} -> {Recase.to_snake(k), v} end)
    |> then(&Validators.array(inner_schema, &1))
    |> then(&Macro.escape/1)
    # Can't unquote the inner_schema beforehand as that would risk evaluating `get_schema`s which don't exist yet.
    # There's probably a better way to do this lol.
    |> then(fn {:custom, {:{}, c, [Validators.Array, :validate, [quoted_inner_schema | args]]}} ->
      {inner_schema, _} = Code.eval_quoted(quoted_inner_schema)
      {:custom, {:{}, c, [Validators.Array, :validate, [inner_schema | args]]}}
    end)
  end

  defp field_to_schema(%{type: "blob"} = field, _nsid) do
    field
    |> Map.take([:accept, :maxSize])
    |> Enum.map(fn {k, v} -> {Recase.to_snake(k), v} end)
    |> Validators.blob()
    |> then(&Macro.escape/1)
  end

  defp field_to_schema(%{type: "bytes"} = field, _nsid) do
    field
    |> Map.take([:maxLength, :minLength])
    |> Enum.map(fn {k, v} -> {Recase.to_snake(k), v} end)
    |> Validators.bytes()
    |> then(&Macro.escape/1)
  end

  defp field_to_schema(%{type: "cid-link"}, _nsid) do
    Validators.cid_link()
    |> then(&Macro.escape/1)
  end

  # TODO: do i need to make sure these two deal with brands? Check objects in atp.tools
  defp field_to_schema(%{type: "ref", ref: ref}, nsid) do
    {nsid, fragment} =
      nsid
      |> Atex.NSID.expand_possible_fragment_shorthand(ref)
      |> Atex.NSID.to_atom_with_fragment()

    quote do
      unquote(nsid).get_schema(unquote(fragment))
    end
  end

  defp field_to_schema(%{type: "union", refs: refs}, nsid) do
    # refs =
    refs
    |> Enum.map(fn ref ->
      {nsid, fragment} =
        nsid
        |> Atex.NSID.expand_possible_fragment_shorthand(ref)
        |> Atex.NSID.to_atom_with_fragment()

      quote do
        unquote(nsid).get_schema(unquote(fragment))
      end
    end)
    |> then(
      &quote do
        {:oneof, unquote(&1)}
      end
    )
  end

  # TODO: apparently should be a data object, not a primitive?
  defp field_to_schema(%{type: "unknown"}, _nsid) do
    :any
  end

  defp field_to_schema(_field_def, _nsid), do: nil

  defp maybe_default(schema, field) do
    if field[:default] != nil,
      do: {schema, {:default, field.default}},
      else: schema
  end

  defp const_or_enum(field), do: const(field) || enum(field)

  defp const(%{const: value}), do: {:literal, value}
  defp const(_), do: nil

  defp enum(%{enum: values}), do: {:enum, values}
  defp enum(_), do: nil

  defp atomise(x) when is_atom(x), do: x
  defp atomise(x) when is_binary(x), do: String.to_atom(x)
end
