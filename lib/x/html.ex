defmodule X.Html do
  @escape_chars [
    {?<, "&lt;"},
    {?>, "&gt;"},
    {?&, "&amp;"},
    {?", "&quot;"},
    {?', "&#39;"}
  ]

  def attrs_to_string(attrs) do
    io_list =
      Enum.reduce(attrs, :first, fn {key, value}, acc ->
        attr_list = [to_string(key), '="', escape(attr_to_string(value)), '"']

        if(acc == :first, do: attr_list, else: [attr_list, ?\s | acc])
      end)

    IO.iodata_to_binary(io_list)
  end

  def attr_to_string(attr = %{__struct__: _}) do
    to_string(attr)
  end

  def attr_to_string(attr) do
    cond do
      is_map(attr) or Keyword.keyword?(attr) ->
        attr
        |> Enum.reduce([], fn {key, value}, acc ->
          (value && [key | acc]) || acc
        end)
        |> Enum.uniq()
        |> Enum.join(" ")

      is_list(attr) ->
        attr |> Enum.join(" ")

      is_tuple(attr) ->
        attr |> Tuple.to_list() |> Enum.join(" ")

      is_binary(attr) ->
        String.trim(attr)

      true ->
        to_string(attr)
    end
  end

  # https://github.com/elixir-plug/plug/blob/master/lib/plug/html.ex
  @spec escape(String.t()) :: String.t()
  def escape(data) when is_binary(data) do
    IO.iodata_to_binary(to_iodata(data, 0, data, []))
  end

  for {match, insert} <- @escape_chars do
    defp to_iodata(<<unquote(match), rest::bits>>, skip, original, acc) do
      to_iodata(rest, skip + 1, original, [acc | unquote(insert)])
    end
  end

  defp to_iodata(<<_char, rest::bits>>, skip, original, acc) do
    to_iodata(rest, skip, original, acc, 1)
  end

  defp to_iodata(<<>>, _skip, _original, acc) do
    acc
  end

  for {match, insert} <- @escape_chars do
    defp to_iodata(<<unquote(match), rest::bits>>, skip, original, acc, len) do
      part = binary_part(original, skip, len)
      to_iodata(rest, skip + len + 1, original, [acc, part | unquote(insert)])
    end
  end

  defp to_iodata(<<_char, rest::bits>>, skip, original, acc, len) do
    to_iodata(rest, skip, original, acc, len + 1)
  end

  defp to_iodata(<<>>, 0, original, _acc, _len) do
    original
  end

  defp to_iodata(<<>>, skip, original, acc, len) do
    [acc | binary_part(original, skip, len)]
  end
end
