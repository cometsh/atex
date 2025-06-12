defmodule Atex.Base32Sortable do
  @moduledoc """
  Codec for the base32-sortable encoding.
  """

  @alphabet ~c(234567abcdefghijklmnopqrstuvwxyz)
  @alphabet_len length(@alphabet)

  @doc """
  Encode an integer as a base32-sortable string.
  """
  @spec encode(integer()) :: String.t()
  def encode(int) when is_integer(int), do: do_encode(int, "")

  @spec do_encode(integer(), String.t()) :: String.t()
  defp do_encode(0, acc), do: acc

  defp do_encode(int, acc) do
    char_index = rem(int, @alphabet_len)
    new_int = div(int, @alphabet_len)

    # Chars are prepended to the accumulator because rem/div is pulling them off the tail of the integer.
    do_encode(new_int, <<Enum.at(@alphabet, char_index)>> <> acc)
  end

  @doc """
  Decode a base32-sortable string to an integer.
  """
  @spec decode(String.t()) :: integer()
  def decode(str) when is_binary(str), do: do_decode(str, 0)

  @spec do_decode(String.t(), integer()) :: integer()
  defp do_decode(<<>>, acc), do: acc

  defp do_decode(<<char::utf8, rest::binary>>, acc) do
    i = Enum.find_index(@alphabet, fn x -> x == char end)
    do_decode(rest, acc * @alphabet_len + i)
  end
end
