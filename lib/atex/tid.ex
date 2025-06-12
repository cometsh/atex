defmodule Atex.TID do
  @moduledoc """
  Struct and helper functions for dealing with AT Protocol TIDs (Timestamp
  Identifiers), a 13-character string representation of a 64-bit number
  comprised of a Unix timestamp (in microsecond precision) and a random "clock
  identifier" to help avoid collisions.

  ATProto spec: https://atproto.com/specs/tid

  TID strings are always 13 characters long. All bits in the 64-bit number are
  encoded, essentially meaning that the string is padded with "2" if necessary,
  (the 0th character in the base32-sortable alphabet).
  """
  import Bitwise
  alias Atex.Base32Sortable
  use TypedStruct

  @re ~r/^[234567abcdefghij][234567abcdefghijklmnopqrstuvwxyz]{12}$/

  @typedoc """
  A Unix timestamp representing when the TID was created.
  """
  @type timestamp() :: integer()

  @typedoc """
  An integer to be used for the lower 10 bits of the TID.
  """
  @type clock_id() :: 0..1023

  typedstruct enforce: true do
    field :timestamp, timestamp()
    field :clock_id, clock_id()
  end

  @doc """
  Returns a TID for the current moment in time, along with a random clock ID.
  """
  @spec now() :: t()
  def now,
    do: %__MODULE__{
      timestamp: DateTime.utc_now(:microsecond) |> DateTime.to_unix(:microsecond),
      clock_id: gen_clock_id()
    }

  @doc """
  Create a new TID from a `DateTime` or an integer representing a Unix timestamp in microseconds.

  If `clock_id` isn't provided, a random one will be generated.
  """
  @spec new(DateTime.t() | integer(), integer() | nil) :: t()
  def new(source, clock_id \\ nil)

  def new(%DateTime{} = datetime, clock_id),
    do: %__MODULE__{
      timestamp: DateTime.to_unix(datetime, :microsecond),
      clock_id: clock_id || gen_clock_id()
    }

  def new(unix, clock_id) when is_integer(unix),
    do: %__MODULE__{timestamp: unix, clock_id: clock_id || gen_clock_id()}

  @doc """
  Convert a TID struct to an instance of `DateTime`.
  """
  def to_datetime(%__MODULE__{} = tid), do: DateTime.from_unix(tid.timestamp, :microsecond)

  @doc """
  Generate a random integer to be used as a `clock_id`.
  """
  @spec gen_clock_id() :: clock_id()
  def gen_clock_id, do: :rand.uniform(1024) - 1

  @doc """
  Decode a TID string into an `Atex.TID` struct, returning an error if it's invalid.

  ## Examples

  Syntactically valid TIDs:

      iex> Atex.TID.decode("3jzfcijpj2z2a")
      {:ok, %Atex.TID{clock_id: 6, timestamp: 1688137381887007}}

      iex> Atex.TID.decode("7777777777777")
      {:ok, %Atex.TID{clock_id: 165, timestamp: 5811096293381285}}

      iex> Atex.TID.decode("3zzzzzzzzzzzz")
      {:ok, %Atex.TID{clock_id: 1023, timestamp: 2251799813685247}}

      iex> Atex.TID.decode("2222222222222")
      {:ok, %Atex.TID{clock_id: 0, timestamp: 0}}

  Invalid TIDs:

      # not base32
      iex> Atex.TID.decode("3jzfcijpj2z21")
      :error
      iex> Atex.TID.decode("0000000000000")
      :error

      # case-sensitive
      iex> Atex.TID.decode("3JZFCIJPJ2Z2A")
      :error

      # too long/short
      iex> Atex.TID.decode("3jzfcijpj2z2aa")
      :error
      iex> Atex.TID.decode("3jzfcijpj2z2")
      :error
      iex> Atex.TID.decode("222")
      :error

      # legacy dash syntax *not* supported (TTTT-TTT-TTTT-CC)
      iex> Atex.TID.decode("3jzf-cij-pj2z-2a")
      :error

      # high bit can't be set
      iex> Atex.TID.decode("zzzzzzzzzzzzz")
      :error
      iex> Atex.TID.decode("kjzfcijpj2z2a")
      :error

  """
  @spec decode(String.t()) :: {:ok, t()} | :error
  def decode(<<timestamp::binary-size(11), clock_id::binary-size(2)>> = tid) do
    if Regex.match?(@re, tid) do
      timestamp = Base32Sortable.decode(timestamp)
      clock_id = Base32Sortable.decode(clock_id)

      {:ok,
       %__MODULE__{
         timestamp: timestamp,
         clock_id: clock_id
       }}
    else
      :error
    end
  end

  def decode(_tid), do: :error

  @doc """
  Encode a TID struct into a string.

  ## Examples

      iex> Atex.TID.encode(%Atex.TID{clock_id: 6, timestamp: 1688137381887007})
      "3jzfcijpj2z2a"

      iex> Atex.TID.encode(%Atex.TID{clock_id: 165, timestamp: 5811096293381285})
      "7777777777777"

      iex> Atex.TID.encode(%Atex.TID{clock_id: 1023, timestamp: 2251799813685247})
      "3zzzzzzzzzzzz"

      iex> Atex.TID.encode(%Atex.TID{clock_id: 0, timestamp: 0})
      "2222222222222"

  """
  @spec encode(t()) :: String.t()
  def encode(%__MODULE__{} = tid) do
    timestamp = tid.timestamp |> Base32Sortable.encode() |> String.pad_leading(11, "2")
    clock_id = (tid.clock_id &&& 1023) |> Base32Sortable.encode() |> String.pad_leading(2, "2")
    timestamp <> clock_id
  end
end

defimpl String.Chars, for: Atex.TID do
  def to_string(tid), do: Atex.TID.encode(tid)
end
