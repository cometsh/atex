defmodule Atex.Lexicon.Schema do
  import Peri

  defschema :lexicon, %{
    lexicon: {:required, {:literal, 1}},
    id:
      {:required,
       {:string,
        {:regex,
         ~r/^[a-zA-Z]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+(\.[a-zA-Z]([a-zA-Z]{0,61}[a-zA-Z])?)$/}}},
    revision: {:integer, {:gte, 0}},
    description: :string,
    defs: {
      :required,
      {:schema,
       %{
         main:
           {:oneof,
            [
              get_schema(:record),
              get_schema(:query),
              get_schema(:procedure),
              get_schema(:subscription),
              get_schema(:user_types)
            ]}
       }, {:additional_keys, get_schema(:user_types)}}
    }
  }

  defschema :record, %{
    type: {:required, {:literal, "record"}},
    description: :string,
    # TODO: constraint
    key: {:required, :string},
    record: {:required, get_schema(:object)}
  }

  defschema :query, %{
    type: {:required, {:literal, "query"}},
    description: :string,
    parameters: get_schema(:parameters),
    output: get_schema(:body),
    errors: {:list, get_schema(:error)}
  }

  defschema :procedure, %{
    type: {:required, {:literal, "procedure"}},
    description: :string,
    parameters: get_schema(:parameters),
    input: get_schema(:body),
    output: get_schema(:body),
    errors: {:list, get_schema(:error)}
  }

  defschema :subscription, %{
    type: {:required, {:literal, "subscription"}},
    description: :string,
    parameters: get_schema(:parameters),
    message: %{
      description: :string,
      schema: {:oneof, [get_schema(:object), get_schema(:ref_variant)]}
    },
    errors: {:list, get_schema(:error)}
  }

  defschema :parameters, %{
    type: {:required, {:literal, "params"}},
    description: :string,
    required: {{:list, :string}, {:default, []}},
    properties:
      {:required, {:map, {:either, {get_schema(:primitive), get_schema(:primitive_array)}}}}
  }

  defschema :body, %{
    description: :string,
    encoding: {:required, :string},
    schema: {:oneof, [get_schema(:object), get_schema(:ref_variant)]}
  }

  defschema :error, %{
    name: {:required, :string},
    description: :string
  }

  defschema :user_types,
            {:oneof,
             [
               get_schema(:blob),
               get_schema(:array),
               get_schema(:token),
               get_schema(:object),
               get_schema(:boolean),
               get_schema(:integer),
               get_schema(:string),
               get_schema(:bytes),
               get_schema(:cid_link),
               get_schema(:unknown)
             ]}

  # General types

  @ref_value {:string,
   {
     :regex,
     # TODO: minlength 1
     ~r/^(?=.)(?:[a-zA-Z](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+(?:\.[a-zA-Z](?:[a-zA-Z]{0,61}[a-zA-Z])?))?(?:#[a-zA-Z](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)?$/
   }}

  @positive_int {:integer, {:gte, 0}}
  @nonzero_positive_int {:integer, {:gt, 0}}

  defschema :ref_variant, {:oneof, [get_schema(:ref), get_schema(:ref_union)]}

  defschema :ref, %{
    type: {:required, {:literal, "ref"}},
    description: :string,
    ref: {:required, @ref_value}
  }

  defschema :ref_union, %{
    type: {:required, {:literal, "union"}},
    description: :string,
    refs: {:required, {:list, @ref_value}}
  }

  defschema :array, %{
    type: {:required, {:literal, "array"}},
    description: :string,
    items:
      {:required,
       {:oneof,
        [get_schema(:primitive), get_schema(:ipld), get_schema(:blob), get_schema(:ref_variant)]}},
    maxLength: @positive_int,
    minLength: @positive_int
  }

  defschema :primitive_array, %{
    type: {:required, {:literal, "array"}},
    description: :string,
    items: {:required, get_schema(:primitive)},
    maxLength: @positive_int,
    minLength: @positive_int
  }

  defschema :object, %{
    type: {:required, {:literal, "object"}},
    description: :string,
    required: {{:list, :string}, {:default, []}},
    nullable: {{:list, :string}, {:default, []}},
    properties:
      {:required,
       {:map,
        {:oneof,
         [
           get_schema(:ref_variant),
           get_schema(:ipld),
           get_schema(:array),
           get_schema(:blob),
           get_schema(:primitive)
         ]}}}
  }

  defschema :primitive,
            {:oneof,
             [
               get_schema(:boolean),
               get_schema(:integer),
               get_schema(:string),
               get_schema(:unknown)
             ]}

  defschema :ipld, {:oneof, [get_schema(:bytes), get_schema(:cid_link)]}

  defschema :blob, %{
    type: {:required, {:literal, "blob"}},
    description: :string,
    accept: {:list, :string},
    maxSize: @positive_int
  }

  defschema :boolean, %{
    type: {:required, {:literal, "boolean"}},
    description: :string,
    default: :boolean,
    const: :boolean
  }

  defschema :bytes, %{
    type: {:required, {:literal, "bytes"}},
    description: :string,
    maxLength: @positive_int,
    minLength: @positive_int
  }

  defschema :cid_link, %{
    type: {:required, {:literal, "cid-link"}},
    description: :string
  }

  @string_type {:required, {:literal, "string"}}

  defschema :string,
            {:either,
             {
               # Formatted
               %{
                 type: @string_type,
                 format:
                   {:required,
                    {:enum,
                     [
                       "at-identifier",
                       "at-uri",
                       "cid",
                       "datetime",
                       "did",
                       "handle",
                       "language",
                       "nsid",
                       "record-key",
                       "tid",
                       "uri"
                     ]}},
                 description: :string,
                 default: :string,
                 const: :string,
                 enum: {:list, :string},
                 knownValues: {:list, :string}
               },
               # Unformatted
               %{
                 type: @string_type,
                 description: :string,
                 default: :string,
                 const: :string,
                 enum: {:list, :string},
                 knownValues: {:list, :string},
                 format: {:literal, nil},
                 maxLength: @nonzero_positive_int,
                 minLength: @nonzero_positive_int,
                 maxGraphemes: @nonzero_positive_int,
                 minGraphemes: @nonzero_positive_int
               }
             }}

  defschema :integer, %{
    type: {:required, {:literal, "integer"}},
    description: :string,
    default: @positive_int,
    const: @positive_int,
    enum: {:list, @positive_int},
    maximum: @positive_int,
    minimum: @positive_int
  }

  defschema :token, %{
    type: {:required, {:literal, "token"}},
    description: :string
  }

  defschema :unknown, %{
    type: {:required, {:literal, "unknown"}},
    description: :string
  }
end
