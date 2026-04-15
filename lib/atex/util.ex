defmodule Atex.Util do
  # IDK why I can't use `:inet.dns_rr_type()`, I get a warning it doesn't exist, but it does.
  @type dns_type() ::
          :a
          | :aaaa
          | :caa
          | :cname
          | :gid
          | :hinfo
          | :ns
          | :mb
          | :md
          | :mg
          | :mf
          | :minfo
          | :mx
          | :naptr
          | :null
          | :ptr
          | :soa
          | :spf
          | :srv
          | :txt
          | :uid
          | :uinfo
          | :unspec
          | :uri
          | :wks

  defguardp is_ipv4(a, b, c, d)
            when is_integer(a) and is_integer(b) and is_integer(c) and is_integer(d)

  defguardp is_ipv4(value)
            when is_tuple(value) and tuple_size(value) == 4 and
                   is_ipv4(elem(value, 0), elem(value, 1), elem(value, 2), elem(value, 3))

  defguardp is_ipv6(a, b, c, d, e, f, g, h)
            when is_integer(a) and is_integer(b) and is_integer(c) and is_integer(d) and
                   is_integer(e) and is_integer(f) and is_integer(g) and is_integer(h)

  defguardp is_ipv6(value)
            when is_tuple(value) and tuple_size(value) == 8 and
                   is_ipv6(
                     elem(value, 0),
                     elem(value, 1),
                     elem(value, 2),
                     elem(value, 3),
                     elem(value, 4),
                     elem(value, 5),
                     elem(value, 6),
                     elem(value, 7)
                   )

  @spec query_dns(String.t(), dns_type()) ::
          list(String.t() | {priority :: integer(), String.t()})
  def query_dns(domain, type) do
    domain
    |> String.to_charlist()
    |> :inet_res.lookup(:in, type)
    |> Enum.map(fn
      [result] ->
        to_string(result)

      value when is_ipv4(value) ->
        format_ipv4(value)

      value when is_ipv6(value) ->
        format_ipv6(value)

      {prio, dns_name} when is_integer(prio) ->
        {prio, to_string(dns_name)}

      result when is_binary(result) ->
        result
    end)
  end

  defp format_ipv4({a, b, c, d}) when is_ipv4(a, b, c, d), do: "#{a}.#{b}.#{c}.#{d}"

  defp format_ipv6({a, b, c, d, e, f, g, h}) when is_ipv6(a, b, c, d, e, f, g, h) do
    [a, b, c, d, e, f, g, h]
    |> Enum.map_join(":", &Integer.to_string(&1, 16))
    |> String.downcase()
  end
end
