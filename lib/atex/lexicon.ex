defmodule Atex.Lexicon do
  alias Atex.Lexicon.Validators

  defmacro __using__(_opts) do
    quote do
      import Atex.Lexicon
      import Atex.Lexicon.Validators
      import Peri
    end
  end

  @doc """
  Defines a lexicon module from a JSON lexicon definition.

  The `deflexicon` macro processes the provided lexicon map (typically loaded
  from a JSON file) and generates:

  - **Typespecs** for each definition, exposing a `t/0` type for the main
    definition and named types for any additional definitions.
  - **`Peri` schemas** via `defschema/2` for runtime validation of data.
  - **Structs** for object and record definitions, with `@enforce_keys` ensuring
    required fields are present.
  - For **queries** and **procedures**, it creates structs for `params`,
    `input`, and `output` when those sections exist in the lexicon. It also
    generates a top‑level struct that aggregates `params` and `input` (when
    applicable); this struct is used by the XRPC client to locate the
    appropriate output struct.

  If a procedure doesn't have a schema for a JSON body specified as it's input,
  the top-level struct will instead have a `raw_input` field, allowing for
  miscellaneous bodies such as a binary blob.

  The generated structs also implement the `JSON.Encoder` and `Jason.Encoder`
  protocols (the latter currently present for compatibility), as well as a
  `from_json` function which is used to validate an input map - e.g. from a JSON
  HTTP response - and turn it into a struct.

  ## Example

      deflexicon(%{
        "lexicon" => 1,
        "id" => "com.ovyerus.testing",
        "defs" => %{
          "main" => %{
            "type" => "record",
            "key" => "tid",
            "record" => %{
              "type" => "object",
              "required" => ["foobar"],
              "properties" => %{ "foobar" => %{ "type" => "string" } }
            }
          }
        }
      })

  The macro expands to following code (truncated for brevity):

      @type main() :: %{required(:foobar) => String.t(), optional(:"$type") => String.t()}
      @type t() :: %{required(:foobar) => String.t(), optional(:"$type") => String.t()}

      defschema(:main, %{
        foobar: {:required, {:custom, {Atex.Lexicon.Validators.String, :validate, [[]]}}},
        "$type": {{:literal, "com.ovyerus.testing"}, {:default, "com.ovyerus.testing"}}
      })

      @enforce_keys [:foobar]
      defstruct foobar: nil, "$type": "com.ovyerus.testing"

      def from_json(json) do
        case apply(Com.Ovyerus.Testing, :main, [json]) do
          {:ok, map} -> {:ok, struct(__MODULE__, map)}
          err -> err
        end
      end

  The generated module can be used directly with `Atex.XRPC` functions, allowing
  type‑safe construction of requests and automatic decoding of responses.
  """
  defmacro deflexicon(lexicon) do
    # Better way to get the real map, without having to eval? (custom function to compose one from quoted?)
    lexicon =
      lexicon
      |> Code.eval_quoted()
      |> elem(0)
      |> then(&Recase.Enumerable.atomize_keys/1)
      |> then(&Atex.Lexicon.Schema.lexicon!/1)

    defs =
      lexicon.defs
      |> Enum.flat_map(fn {def_name, def} -> def_to_schema(lexicon.id, def_name, def) end)
      |> Enum.map(fn
        {schema_key, quoted_schema, quoted_type} -> {schema_key, quoted_schema, quoted_type, nil}
        x -> x
      end)
      |> Enum.map(fn {schema_key, quoted_schema, quoted_type, quoted_struct} ->
        identity_type =
          if schema_key == :main do
            quote do
              @type t() :: unquote(quoted_type)
            end
          end

        struct_def =
          if schema_key == :main do
            quoted_struct
          else
            nested_module_name =
              schema_key
              |> Recase.to_pascal()
              |> atomise()

            quote do
              defmodule unquote({:__aliases__, [alias: false], [nested_module_name]}) do
                unquote(quoted_struct)
              end
            end
          end

        quote do
          @type unquote(Recase.to_snake(schema_key))() :: unquote(quoted_type)
          unquote(identity_type)

          defschema unquote(Recase.to_snake(schema_key)), unquote(quoted_schema)

          unquote(struct_def)
        end
      end)

    quote do
      def id, do: unquote(lexicon.id)

      unquote_splicing(defs)
    end
  end

  # - [ ] `t()` type should be the struct in it. (add to non-main structs too?)

  @spec def_to_schema(nsid :: String.t(), def_name :: String.t(), lexicon_def :: map()) ::
          list(
            {
              key :: atom(),
              quoted_schema :: term(),
              quoted_type :: term()
            }
            | {
                key :: atom(),
                quoted_schema :: term(),
                quoted_type :: term(),
                quoted_struct :: term()
              }
          )

  defp def_to_schema(nsid, def_name, %{type: "record", record: record}) do
    # TODO: record rkey format validator
    type_name = Atex.NSID.canonical_name(nsid, to_string(def_name))

    record =
      put_in(record, [:properties, :"$type"], %{
        type: "string",
        const: type_name,
        default: type_name
      })

    def_to_schema(nsid, def_name, record)
  end

  # TODO: add struct to types
  defp def_to_schema(
         nsid,
         def_name,
         %{
           type: "object",
           properties: properties
         } = def
       ) do
    required = Map.get(def, :required, [])
    nullable = Map.get(def, :nullable, [])

    {quoted_schemas, quoted_types} =
      properties
      |> Enum.map(fn {key, field} ->
        {quoted_schema, quoted_type} = field_to_schema(field, nsid)
        string_key = to_string(key)
        is_nullable = string_key in nullable
        is_required = string_key in required

        quoted_schema =
          quoted_schema
          |> then(
            &if is_nullable, do: quote(do: {:either, {{:literal, nil}, unquote(&1)}}), else: &1
          )
          |> then(&if is_required, do: quote(do: {:required, unquote(&1)}), else: &1)
          |> then(&{key, &1})

        key_type = if is_required, do: :required, else: :optional

        quoted_type =
          quoted_type
          |> then(
            &if is_nullable do
              {:|, [], [&1, nil]}
            else
              &1
            end
          )
          |> then(&{{key_type, [], [key]}, &1})

        {quoted_schema, quoted_type}
      end)
      |> Enum.reduce({[], []}, fn {quoted_schema, quoted_type}, {schemas, types} ->
        {[quoted_schema | schemas], [quoted_type | types]}
      end)

    struct_keys =
      properties
      |> Enum.filter(fn {key, _} -> key !== :"$type" end)
      |> Enum.map(fn
        {key, %{default: default}} -> {key, default}
        {key, _field} -> {key, nil}
      end)
      |> then(&(&1 ++ [{:"$type", if(def_name == :main, do: nsid, else: "#{nsid}##{def_name}")}]))

    enforced_keys =
      properties |> Map.keys() |> Enum.filter(&(to_string(&1) in required && &1 != :"$type"))

    optional_if_nil_keys =
      properties
      |> Map.keys()
      |> Enum.filter(fn key ->
        key = to_string(key)
        # TODO: what if it is nullable but not required?
        key not in required && key not in nullable && key != "$type"
      end)

    schema_module = Atex.NSID.to_atom(nsid)

    quoted_struct =
      quote do
        @enforce_keys unquote(enforced_keys)
        defstruct unquote(struct_keys)

        def from_json(json) do
          case apply(unquote(schema_module), unquote(atomise(def_name)), [json]) do
            {:ok, map} -> {:ok, struct(__MODULE__, map)}
            err -> err
          end
        end

        defimpl JSON.Encoder do
          @optional_if_nil_keys unquote(optional_if_nil_keys)

          def encode(value, encoder) do
            value
            |> Map.from_struct()
            |> Enum.reject(fn {k, v} -> k in @optional_if_nil_keys && v == nil end)
            |> Enum.into(%{})
            |> Jason.Encoder.encode(encoder)
          end
        end

        defimpl Jason.Encoder do
          @optional_if_nil_keys unquote(optional_if_nil_keys)

          def encode(value, options) do
            value
            |> Map.from_struct()
            |> Enum.reject(fn {k, v} -> k in @optional_if_nil_keys && v == nil end)
            |> Enum.into(%{})
            |> Jason.Encode.map(options)
          end
        end
      end

    [{atomise(def_name), {:%{}, [], quoted_schemas}, {:%{}, [], quoted_types}, quoted_struct}]
  end

  # TODO: validating errors?
  defp def_to_schema(nsid, _def_name, %{type: "query"} = def) do
    params =
      if def[:parameters] do
        [schema] =
          def_to_schema(nsid, "params", %{
            type: "object",
            required: Map.get(def.parameters, :required, []),
            properties: def.parameters.properties
          })

        schema
      end

    output =
      if def[:output] && def.output[:schema] do
        [schema] = def_to_schema(nsid, "output", def.output.schema)
        schema
      end

    # Root struct containing `params`
    main =
      if params do
        {
          :main,
          nil,
          quote do
            %__MODULE__{params: params()}
          end,
          quote do
            @enforce_keys [:params]
            defstruct params: nil
          end
        }
      else
        {
          :main,
          nil,
          quote do
            %__MODULE__{}
          end,
          quote do
            defstruct []
          end
        }
      end

    [main, params, output]
    |> Enum.reject(&is_nil/1)
  end

  defp def_to_schema(nsid, _def_name, %{type: "procedure"} = def) do
    # TODO: better keys for these
    params =
      if def[:parameters] do
        [schema] =
          def_to_schema(nsid, "params", %{
            type: "object",
            required: Map.get(def.parameters, :required, []),
            properties: def.parameters.properties
          })

        schema
      end

    output =
      if def[:output] && def.output[:schema] do
        [schema] = def_to_schema(nsid, "output", def.output.schema)
        schema
      end

    input =
      if def[:input] && def.input[:schema] do
        [schema] = def_to_schema(nsid, "input", def.input.schema)
        schema
      end

    # Root struct containing `input`, `raw_input`, and `params`
    main =
      {
        :main,
        nil,
        cond do
          params && input ->
            quote do
              %__MODULE__{input: input(), params: params()}
            end

          input ->
            quote do
              %__MODULE__{input: input()}
            end

          params ->
            quote do
              %__MODULE__{raw_input: any(), params: params()}
            end

          true ->
            quote do
              %__MODULE__{raw_input: any()}
            end
        end,
        cond do
          params && input ->
            quote do
              defstruct input: nil, params: nil
            end

          input ->
            quote do
              defstruct input: nil
            end

          params ->
            quote do
              defstruct raw_input: nil, params: nil
            end

          true ->
            quote do
              defstruct raw_input: nil
            end
        end
      }

    [main, params, output, input]
    |> Enum.reject(&is_nil/1)
  end

  defp def_to_schema(nsid, _def_name, %{type: "subscription"} = def) do
    params =
      if def[:parameters] do
        [schema] =
          def_to_schema(nsid, "params", %{
            type: "object",
            required: Map.get(def.parameters, :required, []),
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
    [
      {
        atomise(def_name),
        :string,
        quote do
          String.t()
        end
      }
    ]
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
              "unknown",
              "ref",
              "union"
            ] do
    {quoted_schema, quoted_type} = field_to_schema(def, nsid)
    [{atomise(def_name), quoted_schema, quoted_type}]
  end

  @spec field_to_schema(field_def :: %{type: String.t()}, nsid :: String.t()) ::
          {quoted_schema :: term(), quoted_typespec :: term()}
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
      |> Validators.string()
      |> maybe_default(field)
    end
    |> then(
      &{Macro.escape(&1),
       quote do
         String.t()
       end}
    )
  end

  defp field_to_schema(%{type: "boolean"} = field, _nsid) do
    (const(field) || :boolean)
    |> maybe_default(field)
    |> then(
      &{Macro.escape(&1),
       quote do
         boolean()
       end}
    )
  end

  defp field_to_schema(%{type: "integer"} = field, _nsid) do
    fixed_schema = const_or_enum(field)

    if fixed_schema do
      maybe_default(fixed_schema, field)
    else
      field
      |> Map.take([:maximum, :minimum])
      |> Keyword.new()
      |> Validators.integer()
      |> maybe_default(field)
    end
    |> then(
      &{
        Macro.escape(&1),
        # TODO: turn into range definition based on maximum/minimum
        quote do
          integer()
        end
      }
    )
  end

  defp field_to_schema(%{type: "array", items: items} = field, nsid) do
    {inner_schema, inner_type} = field_to_schema(items, nsid)

    field
    |> Map.take([:maxLength, :minLength])
    |> Enum.map(fn {k, v} -> {Recase.to_snake(k), v} end)
    |> then(&Validators.array(inner_schema, &1))
    |> then(&Macro.escape/1)
    # TODO: we should be able to unquote this now...
    # Can't unquote the inner_schema beforehand as that would risk evaluating `get_schema`s which don't exist yet.
    # There's probably a better way to do this lol.
    |> then(fn {:custom, {:{}, c, [Validators.Array, :validate, [quoted_inner_schema | args]]}} ->
      {inner_schema, _} = Code.eval_quoted(quoted_inner_schema)
      {:custom, {:{}, c, [Validators.Array, :validate, [inner_schema | args]]}}
    end)
    |> then(
      &{&1,
       quote do
         list(unquote(inner_type))
       end}
    )
  end

  defp field_to_schema(%{type: "blob"} = field, _nsid) do
    field
    |> Map.take([:accept, :maxSize])
    |> Enum.map(fn {k, v} -> {Recase.to_snake(k), v} end)
    |> Validators.blob()
    |> then(
      &{Macro.escape(&1),
       quote do
         Validators.blob()
       end}
    )
  end

  defp field_to_schema(%{type: "bytes"} = field, _nsid) do
    field
    |> Map.take([:maxLength, :minLength])
    |> Enum.map(fn {k, v} -> {Recase.to_snake(k), v} end)
    |> Validators.bytes()
    |> then(
      &{Macro.escape(&1),
       quote do
         Validators.bytes()
       end}
    )
  end

  defp field_to_schema(%{type: "cid-link"}, _nsid) do
    Validators.cid_link()
    |> then(
      &{Macro.escape(&1),
       quote do
         Validators.cid_link()
       end}
    )
  end

  # TODO: do i need to make sure these two deal with brands? Check objects in atp.tools
  defp field_to_schema(%{type: "ref", ref: ref}, nsid) do
    {nsid, fragment} =
      nsid
      |> Atex.NSID.expand_possible_fragment_shorthand(ref)
      |> Atex.NSID.to_atom_with_fragment()

    fragment = Recase.to_snake(fragment)

    {
      Macro.escape(Validators.lazy_ref(nsid, fragment)),
      quote do
        unquote(nsid).unquote(fragment)()
      end
    }
  end

  defp field_to_schema(%{type: "union", refs: refs}, nsid) do
    if refs == [] do
      {quote do
         {:oneof, []}
       end, nil}
    else
      refs
      |> Enum.map(fn ref ->
        {nsid, fragment} =
          nsid
          |> Atex.NSID.expand_possible_fragment_shorthand(ref)
          |> Atex.NSID.to_atom_with_fragment()

        fragment = Recase.to_snake(fragment)

        {
          Macro.escape(Validators.lazy_ref(nsid, fragment)),
          quote do
            unquote(nsid).unquote(fragment)()
          end
        }
      end)
      |> Enum.reduce({[], []}, fn {quoted_schema, quoted_type}, {schemas, types} ->
        {[quoted_schema | schemas], [quoted_type | types]}
      end)
      |> then(fn {schemas, types} ->
        {quote do
           {:oneof, unquote(schemas)}
         end,
         quote do
           unquote(join_with_pipe(types))
         end}
      end)
    end
  end

  # TODO: apparently should be a data object, not a primitive?
  defp field_to_schema(%{type: "unknown"}, _nsid) do
    {:any,
     quote do
       term()
     end}
  end

  defp field_to_schema(_field_def, _nsid), do: {nil, nil}

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

  defp join_with_pipe(list) when is_list(list) do
    [piped] = do_join_with_pipe(list)
    piped
  end

  defp do_join_with_pipe([head]), do: [head]
  defp do_join_with_pipe([head | tail]), do: [{:|, [], [head | do_join_with_pipe(tail)]}]
  defp do_join_with_pipe([]), do: []
end
