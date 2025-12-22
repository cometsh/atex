defmodule Atex.OAuth.Permission do
  use TypedStruct
  import Kernel, except: [to_string: 1]

  @type t_tuple() :: {
          resource :: String.t(),
          positional :: String.t() | nil,
          parameters :: list({String.t(), String.t()})
        }

  @typep as_string() :: {:as_string, boolean()}
  @type account_attr() :: :email | :repo
  @type account_action() :: :read | :manage
  @type account_opt() ::
          {:attr, account_attr()} | {:action, account_action()} | as_string()

  @type repo_opt() ::
          {:create, boolean()} | {:update, boolean()} | {:delete, boolean()} | as_string()

  @type rpc_opt() :: {:aud, String.t()} | {:inherit_aud, boolean()} | as_string()

  @type include_opt() :: {:aud, String.t()} | as_string()

  typedstruct enforce: true do
    field :resource, String.t()
    field :positional, String.t() | nil
    # like a Keyword list but with a string instead of an atom
    field :parameters, list({String.t(), String.t()}), enforce: false, default: []
  end

  @doc """
  Creates a new permission struct from a permission scope string.

  Parses an AT Protocol OAuth permission scope string and returns a structured
  representation. Permission strings follow the format
  `resource:positional?key=value&key2=value2`

  The positional parameter is resource-specific and may be omitted in some cases
  (e.g., collection for `repo`, lxm for `rpc`, attr for `account`/`identity`,
  accept for `blob`).

  See the [AT Protocol
  documentation](https://atproto.com/specs/permission#scope-string-syntax) for
  the full syntax and rules for permission scope strings.

  ## Parameters
  - `string` - A permission scope string (e.g., "repo:app.example.profile")

  Returns `{:ok, permission}` if a valid scope string was given, otherwise it
  will return `{:error, reason}`.

  ## Examples

      # Simple with just a positional
      iex> Atex.OAuth.Permission.new("repo:app.example.profile")
      {:ok, %Atex.OAuth.Permission{
        resource: "repo",
        positional: "app.example.profile",
        parameters: []
      }}

      # With parameters
      iex> Atex.OAuth.Permission.new("repo?collection=app.example.profile&collection=app.example.post")
      {:ok, %Atex.OAuth.Permission{
        resource: "repo",
        positional: nil,
        parameters: [
          {"collection", "app.example.profile"},
          {"collection", "app.example.post"}
        ]
      }}

      # Positional with parameters
      iex> Atex.OAuth.Permission.new("rpc:app.example.moderation.createReport?aud=*")
      {:ok, %Atex.OAuth.Permission{
        resource: "rpc",
        positional: "app.example.moderation.createReport",
        parameters: [{"aud", "*"}]
      }}

      iex> Atex.OAuth.Permission.new("blob:*/*")
      {:ok, %Atex.OAuth.Permission{
        resource: "blob",
        positional: "*/*",
        parameters: []
      }}

      # Invalid: resource without positional or parameters
      iex> Atex.OAuth.Permission.new("resource")
      {:error, :missing_positional_or_parameters}

  """
  @spec new(String.t()) :: {:ok, t()} | {:error, reason :: atom()}
  def new(string) do
    case parse(string) do
      {:ok, {resource, positional, parameters}} ->
        {:ok, %__MODULE__{resource: resource, positional: positional, parameters: parameters}}

      err ->
        err
    end
  end

  @doc """
  Parses an AT Protocol permission scope string into its components.

  Returns a tuple containing the resource name, optional positional parameter,
  and a list of key-value parameter pairs. This is a lower-level function
  compared to `new/1`, returning the raw components instead of a struct.

  ## Parameters
  - `string` - A permission scope string following the format
    `resource:positional?key=value&key2=value2`

  Returns `{:ok, {resource, positional, parameters}}` if a valid scope string
  was given, otherwise it will return `{:error, reason}`.

  ## Examples

      # Simple with just a positional
      iex> Atex.OAuth.Permission.parse("repo:app.example.profile")
      {:ok, {"repo", "app.example.profile", []}}

      # With parameters
      iex> Atex.OAuth.Permission.parse("repo?collection=app.example.profile&collection=app.example.post")
      {:ok, {
        "repo",
        nil,
        [
          {"collection", "app.example.profile"},
          {"collection", "app.example.post"}
        ]
      }}

      # Positional with parameters
      iex> Atex.OAuth.Permission.parse("rpc:app.example.moderation.createReport?aud=*")
      {:ok, {"rpc", "app.example.moderation.createReport", [{"aud", "*"}]}}

      iex> Atex.OAuth.Permission.parse("blob:*/*")
      {:ok, {"blob", "*/*", []}}

      # Invalid: resource without positional or parameters
      iex> Atex.OAuth.Permission.parse("resource")
      {:error, :missing_positional_or_parameters}

  """
  @spec parse(String.t()) ::
          {:ok, t_tuple()}
          | {:error, reason :: atom()}
  def parse(string) do
    case String.split(string, "?", parts: 2) do
      [resource_part] ->
        parse_resource_and_positional(resource_part)

      # Empty parameter string is treated as absent
      [resource_part, ""] ->
        parse_resource_and_positional(resource_part)

      [resource_part, params_part] ->
        params_part
        |> parse_parameters()
        |> then(&parse_resource_and_positional(resource_part, &1))
    end
  end

  @spec parse_resource_and_positional(String.t(), list({String.t(), String.t()})) ::
          {:ok, t_tuple()} | {:error, reason :: atom()}
  defp parse_resource_and_positional(resource_part, parameters \\ []) do
    case String.split(resource_part, ":", parts: 2) do
      [resource_name, positional] ->
        {:ok, {resource_name, positional, parameters}}

      [resource_name] ->
        if parameters == [] do
          {:error, :missing_positional_or_parameters}
        else
          {:ok, {resource_name, nil, parameters}}
        end
    end
  end

  @spec parse_parameters(String.t()) :: list({String.t(), String.t()})
  defp parse_parameters(params_string) do
    params_string
    |> String.split("&")
    |> Enum.map(fn param ->
      case String.split(param, "=", parts: 2) do
        [key, value] -> {key, URI.decode(value)}
        [key] -> {key, ""}
      end
    end)
  end

  @doc """
  Converts a permission struct back into its scope string representation.

  This is the inverse operation of `new/1`, converting a structured permission
  back into the AT Protocol OAuth scope string format. The resulting string
  can be used directly as an OAuth scope parameter.

  Values in `parameters` are automatically URL-encoded as needed (e.g., `#` becomes `%23`).

  ## Parameters
  - `struct` - An `%Atex.OAuth.Permission{}` struct

  Returns a permission scope string.

  ## Examples

      # Simple with just a positional
      iex> perm = %Atex.OAuth.Permission{
      ...>   resource: "repo",
      ...>   positional: "app.example.profile",
      ...>   parameters: []
      ...> }
      iex> Atex.OAuth.Permission.to_string(perm)
      "repo:app.example.profile"

      # With parameters
      iex> perm = %Atex.OAuth.Permission{
      ...>   resource: "repo",
      ...>   positional: nil,
      ...>   parameters: [
      ...>     {"collection", "app.example.profile"},
      ...>     {"collection", "app.example.post"}
      ...>   ]
      ...> }
      iex> Atex.OAuth.Permission.to_string(perm)
      "repo?collection=app.example.profile&collection=app.example.post"

      # Positional with parameters
      iex> perm = %Atex.OAuth.Permission{
      ...>   resource: "rpc",
      ...>   positional: "app.example.moderation.createReport",
      ...>   parameters: [{"aud", "*"}]
      ...> }
      iex> Atex.OAuth.Permission.to_string(perm)
      "rpc:app.example.moderation.createReport?aud=*"

      iex> perm = %Atex.OAuth.Permission{
      ...>   resource: "blob",
      ...>   positional: "*/*",
      ...>   parameters: []
      ...> }
      iex> Atex.OAuth.Permission.to_string(perm)
      "blob:*/*"

      # Works via String.Chars protocol
      iex> perm = %Atex.OAuth.Permission{
      ...>   resource: "account",
      ...>   positional: "email",
      ...>   parameters: []
      ...> }
      iex> to_string(perm)
      "account:email"

  """
  @spec to_string(t()) :: String.t()
  def to_string(%__MODULE__{} = struct) do
    positional_part = if struct.positional, do: ":#{struct.positional}", else: ""
    parameters_part = stringify_parameters(struct.parameters)

    struct.resource <> positional_part <> parameters_part
  end

  @spec stringify_parameters(list({String.t(), String.t()})) :: String.t()
  defp stringify_parameters([]), do: ""

  defp stringify_parameters(params) do
    params
    |> Enum.map(fn {key, value} -> "#{key}=#{encode_param_value(value)}" end)
    |> Enum.join("&")
    |> then(&"?#{&1}")
  end

  # Encode parameter values for OAuth scope strings
  # Preserves unreserved characters (A-Z, a-z, 0-9, -, ., _, ~) and common scope characters (*, :, /)
  # Encodes reserved characters like # as %23
  @spec encode_param_value(String.t()) :: String.t()
  defp encode_param_value(value) do
    URI.encode(value, fn char ->
      URI.char_unreserved?(char) or char in [?*, ?:, ?/]
    end)
  end

  @doc """
  Creates an account permission for controlling PDS account hosting details.

  Controls access to private account information such as email address and
  repository import capabilities. These permissions cannot be included in
  permission sets and must be requested directly by client apps.

  See the [AT Protocol documentation](https://atproto.com/specs/permission#account)
  for more information.

  ## Options
  - `:attr` (required) - A component of account configuration. Must be `:email`
    or `:repo`.
  - `:action` (optional) - Degree of control. Can be `:read` or `:manage`.
    Defaults to `:read`.
  - `:as_string` (optional) - If `true` (default), returns a scope string,
    otherwise returns a Permission struct.

  If `:as_string` is true a scope string is returned, otherwise the underlying
  Permission struct is returned.

  ## Examples

      # Read account email (default action, as string)
      iex> Atex.OAuth.Permission.account(attr: :email)
      "account:email"

      # Read account email (as struct)
      iex> Atex.OAuth.Permission.account(attr: :email, as_string: false)
      %Atex.OAuth.Permission{
        resource: "account",
        positional: "email",
        parameters: []
      }

      # Read account email (explicit action)
      iex> Atex.OAuth.Permission.account(attr: :email, action: :read)
      "account:email?action=read"

      # Manage account email
      iex> Atex.OAuth.Permission.account(attr: :email, action: :manage)
      "account:email?action=manage"

      # Import repo
      iex> Atex.OAuth.Permission.account(attr: :repo, action: :manage)
      "account:repo?action=manage"

  """
  @spec account(list(account_opt())) :: t() | String.t()
  def account(opts \\ []) do
    opts = Keyword.validate!(opts, attr: nil, action: nil, as_string: true)
    attr = Keyword.get(opts, :attr)
    action = Keyword.get(opts, :action)
    as_string = Keyword.get(opts, :as_string)

    cond do
      is_nil(attr) ->
        raise ArgumentError, "option `:attr` must be provided."

      attr not in [:email, :repo] ->
        raise ArgumentError, "option `:attr` must be `:email` or `:repo`."

      action not in [nil, :read, :manage] ->
        raise ArgumentError, "option `:action` must be `:read`, `:manage`, or `nil`."

      true ->
        struct = %__MODULE__{
          resource: "account",
          positional: Atom.to_string(attr),
          parameters: if(!is_nil(action), do: [{"action", Atom.to_string(action)}], else: [])
        }

        if as_string, do: to_string(struct), else: struct
    end
  end

  @doc """
  Creates a blob permission for uploading media files to PDS.

  Controls the ability to upload blobs (media files) to the PDS. Permissions can
  be restricted by MIME type patterns.

  See the [AT Protocol documentation](https://atproto.com/specs/permission#blob)
  for more information.

  <!-- TODO: When permission sets are supported, add the note from the docs about this not being allowed in permisison sets. -->

  ## Parameters
  - `accept` - A single MIME type string or list of MIME type strings/patterns.
    Supports glob patterns like `"*/*"` or `"video/*"`.
  - `opts` - Keyword list of options.

  ## Options
    - `:as_string` (optional) - If `true` (default), returns a scope string, otherwise
    returns a Permission struct.

  If `:as_string` is true a scope string is returned, otherwise the underlying
  Permission struct is returned.

  ## Examples

      # Upload any type of blob
      iex> Atex.OAuth.Permission.blob("*/*")
      "blob:*/*"

      # Only images
      iex> Atex.OAuth.Permission.blob("image/*", as_string: false)
      %Atex.OAuth.Permission{
        resource: "blob",
        positional: "image/*",
        parameters: []
      }

      # Multiple mimetypes
      iex> Atex.OAuth.Permission.blob(["video/*", "text/html"])
      "blob?accept=video/*&accept=text/html"

      # Multiple more specific mimetypes
      iex> Atex.OAuth.Permission.blob(["image/png", "image/jpeg"], as_string: false)
      %Atex.OAuth.Permission{
        resource: "blob",
        positional: nil,
        parameters: [{"accept", "image/png"}, {"accept", "image/jpeg"}]
      }

  """
  # TODO: should probably validate that these at least look like mimetypes (~r"^.+/.+$")
  @spec blob(String.t() | list(String.t()), list(as_string())) :: t() | String.t()
  def blob(accept, opts \\ [])

  def blob(accept, opts) when is_binary(accept) do
    opts = Keyword.validate!(opts, as_string: true)
    as_string = Keyword.get(opts, :as_string)
    struct = %__MODULE__{resource: "blob", positional: accept}
    if as_string, do: to_string(struct), else: struct
  end

  def blob(accept, opts) when is_list(accept) do
    opts = Keyword.validate!(opts, as_string: true)
    as_string = Keyword.get(opts, :as_string)

    struct = %__MODULE__{
      resource: "blob",
      positional: nil,
      parameters: Enum.map(accept, &{"accept", &1})
    }

    if as_string, do: to_string(struct), else: struct
  end

  @doc """
  Creates an identity permission for controlling network identity.

  Controls access to the account's DID document and handle. Note that the PDS
  might not be able to facilitate identity changes if it does not have control
  over the DID document (e.g., when using `did:web`).

  <!-- TODO: same thing about not allowed in permission sets. -->

  See the [AT Protocol
  documentation](https://atproto.com/specs/permission#identity) for more
  information.

  ## Parameters
  - `attr` - An aspect or component of identity. Must be `:handle` or `:*`
    (wildcard).
  - `opts` - Keyword list of options.

  ## Options
    - `:as_string` (optional) - If `true` (default), returns a scope string,
    otherwise returns a Permission struct.

  If `:as_string` is true a scope string is returned, otherwise the underlying
  Permission struct is returned.

  ## Examples

      # Update account handle (as string)
      iex> Atex.OAuth.Permission.identity(:handle)
      "identity:handle"

      # Full identity control (as struct)
      iex> Atex.OAuth.Permission.identity(:*, as_string: false)
      %Atex.OAuth.Permission{
        resource: "identity",
        positional: "*",
        parameters: []
      }

  """
  @spec identity(:handle | :*, list(as_string())) :: t() | String.t()
  def identity(attr, opts \\ []) when attr in [:handle, :*] do
    opts = Keyword.validate!(opts, as_string: true)
    as_string = Keyword.get(opts, :as_string)

    struct = %__MODULE__{
      resource: "identity",
      positional: Atom.to_string(attr)
    }

    if as_string, do: to_string(struct), else: struct
  end

  @doc """
  Creates a repo permission for write access to records in the account's public
  repository.

  Controls write access to specific record types (collections) with optional
  restrictions on the types of operations allowed (create, update, delete).

  When no options are provided, all operations are permitted. When any action
  option is explicitly set, only the actions set to `true` are enabled. This
  allows for precise control over permissions.

  See the [AT Protocol documentation](https://atproto.com/specs/permission#repo)
  for more information.

  ## Parameters
  - `collection_or_collections` - A single collection NSID string or list of
    collection NSIDs. Use `"*"` for wildcard access to all record types (not
    allowed in permission sets).
  - `options` - Keyword list to restrict operations. If omitted, all operations
    are allowed. If any action is specified, only explicitly enabled actions are
    permitted.

  ## Options
  - `:create` - Allow creating new records.
  - `:update` - Allow updating existing records.
  - `:delete` - Allow deleting records.
  - `:as_string` (optional) - If `true` (default), returns a scope string,
    otherwise returns a Permission struct.

  If `:as_string` is true a scope string is returned, otherwise the underlying
  Permission struct is returned.

  ## Examples

      # Full permission on a single record type (all actions enabled, actions omitted)
      iex> Atex.OAuth.Permission.repo("app.example.profile")
      "repo:app.example.profile"

      # Create only permission (other actions implicitly disabled)
      iex> Atex.OAuth.Permission.repo("app.example.post", create: true, as_string: false)
      %Atex.OAuth.Permission{
        resource: "repo",
        positional: "app.example.post",
        parameters: [{"action", "create"}]
      }

      # Delete only permission
      iex> Atex.OAuth.Permission.repo("app.example.like", delete: true)
      "repo:app.example.like?action=delete"

      # Create and update only, delete implicitly disabled
      iex> Atex.OAuth.Permission.repo("app.example.repost", create: true, update: true)
      "repo:app.example.repost?action=update&action=create"

      # Multiple collections with full permissions (no options provided, actions omitted)
      iex> Atex.OAuth.Permission.repo(["app.example.profile", "app.example.post"])
      "repo?collection=app.example.profile&collection=app.example.post"

      # Multiple collections with only update permission (as struct)
      iex> Atex.OAuth.Permission.repo(["app.example.like", "app.example.repost"], update: true, as_string: false)
      %Atex.OAuth.Permission{
        resource: "repo",
        positional: nil,
        parameters: [
          {"collection", "app.example.like"},
          {"collection", "app.example.repost"},
          {"action", "update"}
        ]
      }

      # Wildcard permission (all record types, all actions enabled, actions omitted)
      iex> Atex.OAuth.Permission.repo("*")
      "repo:*"
  """
  @spec repo(String.t() | list(String.t()), list(repo_opt())) :: t() | String.t()
  def repo(collection_or_collections, actions \\ [create: true, update: true, delete: true])

  def repo(_collection, []),
    do:
      raise(
        ArgumentError,
        ":actions must not be an empty list. If you want to have all actions enabled, either set them explicitly or remove the empty list argument."
      )

  def repo(collection, actions) when is_binary(collection), do: repo([collection], actions)

  def repo(collections, actions) when is_list(collections) do
    actions =
      Keyword.validate!(actions, [:create, :update, :delete, as_string: true])

    # Check if any action keys were explicitly provided
    has_explicit_actions =
      Keyword.has_key?(actions, :create) ||
        Keyword.has_key?(actions, :update) ||
        Keyword.has_key?(actions, :delete)

    # If no action keys provided, default all to true; otherwise use explicit values
    create = if has_explicit_actions, do: Keyword.get(actions, :create, false), else: true
    update = if has_explicit_actions, do: Keyword.get(actions, :update, false), else: true
    delete = if has_explicit_actions, do: Keyword.get(actions, :delete, false), else: true
    all_actions_true = create && update && delete

    as_string = Keyword.get(actions, :as_string)
    singular_collection = length(collections) == 1
    collection_parameters = Enum.map(collections, &{"collection", &1})

    parameters =
      []
      |> add_repo_param(:create, create, all_actions_true)
      |> add_repo_param(:update, update, all_actions_true)
      |> add_repo_param(:delete, delete, all_actions_true)
      |> add_repo_param(:collections, collection_parameters)

    struct = %__MODULE__{
      resource: "repo",
      positional: if(singular_collection, do: hd(collections)),
      parameters: parameters
    }

    if as_string, do: to_string(struct), else: struct
  end

  # When all actions are true, omit them
  defp add_repo_param(list, _type, _value, true), do: list
  # Otherwise add them in
  defp add_repo_param(list, :create, true, false), do: [{"action", "create"} | list]
  defp add_repo_param(list, :update, true, false), do: [{"action", "update"} | list]
  defp add_repo_param(list, :delete, true, false), do: [{"action", "delete"} | list]

  # Catch-all for 4-arity version (must be before 3-arity)
  defp add_repo_param(list, _type, _value, _all_true), do: list

  defp add_repo_param(list, :collections, [_ | [_ | _]] = collections),
    do: Enum.concat(collections, list)

  defp add_repo_param(list, _type, _value), do: list

  @doc """
  Creates an RPC permission for authenticated API requests to remote services.

  The permission is parameterised by the remote endpoint (`lxm`, short for
  "Lexicon Method") and the identity of the remote service (the audience,
  `aud`). Permissions must be restricted by at least one of these parameters.

  See the [AT Protocol documentation](https://atproto.com/specs/permission#rpc)
  for more information.

  ## Parameters
  - `lxm` - A single NSID string or list of NSID strings representing API
    endpoints. Use `"*"` for wildcard access to all endpoints.
  - `opts` - Keyword list of options.

  ## Options
    - `:aud` (semi-required) - Audience of API requests as a DID service
      reference (e.g., `"did:web:api.example.com#srvtype"`). Supports wildcard
      (`"*"`).
    - `:inherit_aud` (optional) - If `true`, the `aud` value will be inherited
      from permission set invocation context. Only used inside permission sets.
    - `:as_string` (optional) - If `true` (default), returns a scope string,
      otherwise returns a Permission struct.

  > #### Note {: .info}
  >
  > `aud` and `lxm` cannot both be wildcard. The permission must be restricted
  > by at least one of them.

  If `:as_string` is true a scope string is returned, otherwise the underlying
  Permission struct is returned.

  ## Examples

      # Single endpoint with wildcard audience (as string)
      iex> Atex.OAuth.Permission.rpc("app.example.moderation.createReport", aud: "*")
      "rpc:app.example.moderation.createReport?aud=*"

      # Multiple endpoints with specific service (as struct)
      iex> Atex.OAuth.Permission.rpc(
      ...>   ["app.example.getFeed", "app.example.getProfile"],
      ...>   aud: "did:web:api.example.com#svc_appview",
      ...>   as_string: false
      ...> )
      %Atex.OAuth.Permission{
        resource: "rpc",
        positional: nil,
        parameters: [
          {"aud", "did:web:api.example.com#svc_appview"},
          {"lxm", "app.example.getFeed"},
          {"lxm", "app.example.getProfile"}
        ]
      }

      # Wildcard method with specific service
      iex> Atex.OAuth.Permission.rpc("*", aud: "did:web:api.example.com#svc_appview")
      "rpc:*?aud=did:web:api.example.com%23svc_appview"

      # Single endpoint with inherited audience (for permission sets)
      iex> Atex.OAuth.Permission.rpc("app.example.getPreferences", inherit_aud: true)
      "rpc:app.example.getPreferences?inheritAud=true"

  """
  @spec rpc(String.t() | list(String.t()), list(rpc_opt())) :: t() | String.t()
  def rpc(lxm_or_lxms, opts \\ [])
  def rpc(lxm, opts) when is_binary(lxm), do: rpc([lxm], opts)

  def rpc(lxms, opts) when is_list(lxms) do
    opts = Keyword.validate!(opts, aud: nil, inherit_aud: false, as_string: true)
    aud = Keyword.get(opts, :aud)
    inherit_aud = Keyword.get(opts, :inherit_aud)
    as_string = Keyword.get(opts, :as_string)

    # Validation: must have at least one of aud or inherit_aud
    cond do
      is_nil(aud) && !inherit_aud ->
        raise ArgumentError,
              "RPC permissions must specify either `:aud` or `:inheritAud` option."

      !is_nil(aud) && inherit_aud ->
        raise ArgumentError,
              "RPC permissions cannot specify both `:aud` and `:inheritAud` options."

      # Both lxm and aud cannot be wildcard
      length(lxms) == 1 && hd(lxms) == "*" && aud == "*" ->
        raise ArgumentError, "RPC permissions cannot have both wildcard `lxm` and wildcard `aud`."

      true ->
        singular_lxm = length(lxms) == 1
        lxm_parameters = Enum.map(lxms, &{"lxm", &1})

        parameters =
          cond do
            inherit_aud && singular_lxm ->
              [{"inheritAud", "true"}]

            inherit_aud ->
              [{"inheritAud", "true"} | lxm_parameters]

            singular_lxm ->
              [{"aud", aud}]

            true ->
              [{"aud", aud} | lxm_parameters]
          end

        struct = %__MODULE__{
          resource: "rpc",
          positional: if(singular_lxm, do: hd(lxms)),
          parameters: parameters
        }

        if as_string, do: to_string(struct), else: struct
    end
  end

  @doc """
  Creates an include permission for referencing a permission set.

  Permission sets are Lexicon schemas that bundle together multiple permissions
  under a single NSID. This allows developers to request a group of related
  permissions with a single scope string, improving user experience by reducing
  the number of individual permissions that need to be reviewed.

  The `nsid` parameter is required and must be a valid NSID that resolves to a
  permission set Lexicon schema. An optional `aud` parameter can be used to specify
  the audience for any RPC permissions within the set that have `inheritAud: true`.

  See the [AT Protocol documentation](https://atproto.com/specs/permission#permission-sets)
  for more information.

  ## Parameters
  - `nsid` - The NSID of the permission set (e.g., "com.example.authBasicFeatures")
  - `opts` - Keyword list of options.

  ## Options
    - `:aud` (optional) - Audience of API requests as a DID service reference
      (e.g., "did:web:api.example.com#srvtype"). Supports wildcard (`"*"`).
    - `:as_string` (optional) - If `true` (default), returns a scope string,
      otherwise returns a Permission struct.

  If `:as_string` is true a scope string is returned, otherwise the underlying
  Permission struct is returned.

  ## Examples

      # Include a permission set (as string)
      iex> Atex.OAuth.Permission.include("com.example.authBasicFeatures")
      "include:com.example.authBasicFeatures"

      # Include a permission set with audience (as struct)
      iex> Atex.OAuth.Permission.include("com.example.authFull", aud: "did:web:api.example.com#svc_chat", as_string: false)
      %Atex.OAuth.Permission{
        resource: "include",
        positional: "com.example.authFull",
        parameters: [{"aud", "did:web:api.example.com#svc_chat"}]
      }

      # Include a permission set with wildcard audience
      iex> Atex.OAuth.Permission.include("app.example.authFull", aud: "*")
      "include:app.example.authFull?aud=*"

  """
  @spec include(String.t(), list(include_opt())) :: t() | String.t()
  def include(nsid, opts \\ []) do
    opts = Keyword.validate!(opts, aud: nil, as_string: true)
    aud = Keyword.get(opts, :aud)
    as_string = Keyword.get(opts, :as_string)

    parameters = if !is_nil(aud), do: [{"aud", aud}], else: []

    struct = %__MODULE__{
      resource: "include",
      positional: nsid,
      parameters: parameters
    }

    if as_string, do: to_string(struct), else: struct
  end
end

defimpl String.Chars, for: Atex.OAuth.Permission do
  def to_string(permission), do: Atex.OAuth.Permission.to_string(permission)
end
