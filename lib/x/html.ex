defmodule X.Html do
  @escape_chars [
    {?<, "&lt;"},
    {?>, "&gt;"},
    {?&, "&amp;"},
    {?", "&quot;"},
    {?', "&#39;"}
  ]

  @merge_attr_names ["class", "style"]

  @spec merge_attrs(any(), any()) :: [{String.t(), any()}]
  def merge_attrs(base_attrs, merge_attrs) do
    merge_attrs = value_to_key_list(merge_attrs)

    {merged_attrs, rest_attrs} =
      base_attrs
      |> value_to_key_list()
      |> Enum.reduce({[], merge_attrs}, fn {b_key, b_value}, {acc, merge_attrs} ->
        case List.keytake(merge_attrs, b_key, 0) do
          {{m_key, m_value}, rest} when m_key in @merge_attr_names ->
            {[{m_key, merge_attrs(b_value, m_value)} | acc], rest}

          {m_attr, rest} ->
            {[m_attr | acc], rest}

          nil ->
            {[{b_key, b_value} | acc], merge_attrs}
        end
      end)

    rest_attrs ++ merged_attrs
  end

  @spec attrs_to_string(map() | [{atom() | String.t(), any()}]) :: String.t()
  def attrs_to_string(attrs) when is_map(attrs) or is_list(attrs) do
    attrs
    |> Enum.reduce(:first, fn
      {_, false}, acc ->
        acc

      {key, value}, acc ->
        string_key = to_string(key)
        string_value = escape(attr_value_to_string(value, string_key))
        attr_list = [string_key, '="', string_value, '"']

        if(acc == :first, do: attr_list, else: [attr_list, ?\s | acc])
    end)
    |> IO.iodata_to_binary()
  end

  @spec attr_value_to_string(any()) :: String.t()
  def attr_value_to_string(value) do
    attr_value_to_string(value, "")
  end

  @spec attr_value_to_string(any(), String.t()) :: String.t()
  def attr_value_to_string(value = %{__struct__: _}, _) do
    to_string(value)
  end

  def attr_value_to_string(value, key) when is_tuple(value) do
    value
    |> Tuple.to_list()
    |> attr_value_to_string(key)
  end

  def attr_value_to_string(value, _) when is_binary(value) do
    value
  end

  def attr_value_to_string(true, _) do
    "true"
  end

  def attr_value_to_string(value, _) when is_number(value) do
    to_string(value)
  end

  def attr_value_to_string(value, key) when is_map(value) and key not in @merge_attr_names do
    X.json_library().encode!(value)
  end

  def attr_value_to_string(value, key) when is_map(value) or is_list(value) do
    delimiter =
      case key do
        "style" -> ?;
        _ -> ?\s
      end

    value
    |> Enum.reduce(:first, fn
      {_, value}, acc when is_nil(value) or value == false ->
        acc

      elem, acc ->
        result =
          case elem do
            {key, value} when is_binary(value) -> [to_string(key), ?:, value]
            {key, value} when is_number(value) -> [to_string(key), ?:, to_string(value)]
            {key, true} -> to_string(key)
            key -> to_string(key)
          end

        if(acc == :first, do: result, else: [result, delimiter | acc])
    end)
    |> IO.iodata_to_binary()
  end

  def to_safe_string(value) when is_binary(value) do
    escape(value)
  end

  def to_safe_string(value) when is_number(value) do
    to_string(value)
  end

  def to_safe_string(value) do
    escape(to_string(value))
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

  @spec value_to_key_list(any()) :: [{String.t(), any()}]
  defp value_to_key_list(nil) do
    []
  end

  defp value_to_key_list(value) when is_map(value) or is_list(value) do
    Enum.reduce(value, [], fn
      {key, value}, acc -> [{to_string(key), value} | acc]
      [], acc -> acc
      key, acc -> [{to_string(key), true} | acc]
    end)
  end

  defp value_to_key_list(value) do
    [{to_string(value), true}]
  end
end
