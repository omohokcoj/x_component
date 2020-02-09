defmodule X.Html do
  @moduledoc """
  Contains a set of functions to build a valid and safe HTML from X templates.
  """

  @escape_chars [
    {?<, "&lt;"},
    {?>, "&gt;"},
    {?&, "&amp;"},
    {?", "&quot;"},
    {?', "&#39;"}
  ]

  @merge_attr_names ["class", "style"]

  @doc ~S"""
  Merges given attrs and returns a list with key-value tuples:

      iex> X.Html.merge_attrs(%{demo: true, env: "test"}, [demo: false])
      [{"env", "test"}, {"demo", false}]

  It doesn't override `"style"` and `"class"` attributes from `base_attrs`
  but adds merged values into the list:

      iex> X.Html.merge_attrs(
      ...>   %{style: [{"color", "#fff"}, {"size", 1}]},
      ...>   [style: [{"color", "#aaa"}, {"font", "test"}]]
      ...> )
      [{"style", [{"size", 1}, {"color", "#aaa"}, {"font", "test"}]}]
  """
  @spec merge_attrs(any(), any()) :: [{String.t(), any()}]
  def merge_attrs(base_attrs, merge_attrs) do
    merge_attrs = value_to_key_list(merge_attrs)

    base_attrs
    |> value_to_key_list()
    |> Enum.reduce(merge_attrs, fn {b_key, b_value}, acc ->
      case List.keytake(acc, b_key, 0) do
        {{m_key, m_value}, rest} when m_key in @merge_attr_names ->
          [{m_key, merge_attrs(b_value, m_value)} | rest]

        {m_attr, rest} ->
          [m_attr | rest]

        nil ->
          [{b_key, b_value} | acc]
      end
    end)
  end

  @doc ~S"""
  Converts given attrs into HTML-safe iodata:

      iex> X.Html.attrs_to_iodata(%{"demo" => true, "env" => "<test>"})
      [["demo", '="', "true", '"'], 32, "env", '="', [[[] | "&lt;"], "test" | "&gt;"], '"']
  """
  @spec attrs_to_iodata(map() | [{String.t(), any()}]) :: iodata()
  def attrs_to_iodata(attrs) when is_map(attrs) do
    attrs
    |> Map.to_list()
    |> attrs_to_iodata()
  end

  def attrs_to_iodata([{_, value} | tail]) when value in [nil, false] do
    attrs_to_iodata(tail)
  end

  def attrs_to_iodata([{key, value} | tail]) do
    value_iodata = attr_value_to_iodata(value, key)
    attr_list = [key, '="', value_iodata, '"']

    case {tail, attrs_to_iodata(tail)} do
      {_, []} -> attr_list
      {[], acc} -> [attr_list | acc]
      {_, acc} -> [attr_list, ?\s | acc]
    end
  end

  def attrs_to_iodata([]) do
    []
  end

  @doc ~S"""
  Converts attr value into HTML-safe iodata:

      iex> X.Html.attr_value_to_iodata("<test>")
      [[[] | "&lt;"], "test" | "&gt;"]

  `"style"` and `"class"` attr values are joined with a delimiter:

      iex> X.Html.attr_value_to_iodata([{"color", "#fff"}, {"font", "small"}], "style")
      [["color", ": ", "#fff"], "; ", ["font", ": ", "small"]]
  """
  @spec attr_value_to_iodata(any()) :: iodata()
  @spec attr_value_to_iodata(any(), String.t()) :: iodata()
  def attr_value_to_iodata(value, key \\ "")

  def attr_value_to_iodata(true, _) do
    "true"
  end

  def attr_value_to_iodata(value, key) when is_map(value) and key not in @merge_attr_names do
    to_safe_iodata(value)
  end

  def attr_value_to_iodata(value, key) when is_map(value) or is_list(value) do
    delimiter = if(key == "style", do: "; ", else: " ")

    value
    |> Enum.to_list()
    |> join_values_to_iodata(delimiter)
  end

  def attr_value_to_iodata(value, _) do
    to_safe_iodata(value)
  end

  @doc ~S"""
  Converts given value into HTML-safe iodata:

      iex> X.Html.to_safe_iodata("<test>")
      [[[] | "&lt;"], "test" | "&gt;"]
  """
  @spec to_safe_iodata(any()) :: iodata()
  def to_safe_iodata(value) when is_binary(value) do
    escape_to_iodata(value, 0, value, [])
  end

  def to_safe_iodata(value) when is_integer(value) do
    :erlang.integer_to_binary(value)
  end

  def to_safe_iodata(value) when is_float(value) do
    :io_lib_format.fwrite_g(value)
  end

  def to_safe_iodata(value = %module{}) when module in [Date, Time, NaiveDateTime, Decimal] do
    module.to_string(value)
  end

  def to_safe_iodata(value = %DateTime{}) do
    value
    |> to_string()
    |> to_safe_iodata()
  end

  if Code.ensure_compiled?(X.json_library()) do
    def to_safe_iodata(value) when is_map(value) do
      value
      |> X.json_library().encode!(%{escape: :html_safe})
      |> to_safe_iodata()
    end
  end

  def to_safe_iodata(value) do
    value
    |> to_string()
    |> to_safe_iodata()
  end

  @spec value_to_key_list(any()) :: [{String.t(), any()}]
  defp value_to_key_list([head | tail]) do
    result =
      case head do
        {key, value} -> {to_string(key), value}
        key -> {to_string(key), true}
      end

    [result | value_to_key_list(tail)]
  end

  defp value_to_key_list([]) do
    []
  end

  defp value_to_key_list(value) when is_map(value) do
    value
    |> Map.to_list()
    |> value_to_key_list()
  end

  defp value_to_key_list(value) when is_tuple(value) do
    [{value, true}]
  end

  defp value_to_key_list(value) do
    [{to_string(value), true}]
  end

  @spec join_values_to_iodata([{any(), any()}], String.t()) :: iodata()
  defp join_values_to_iodata([{_, value} | tail], delimiter) when value in [nil, false] do
    join_values_to_iodata(tail, delimiter)
  end

  defp join_values_to_iodata([head | tail], delimiter) do
    result =
      case head do
        {key, true} ->
          to_safe_iodata(key)

        {key, value} ->
          [to_safe_iodata(key), ": ", to_safe_iodata(value)]

        key ->
          to_safe_iodata(key)
      end

    case {tail, join_values_to_iodata(tail, delimiter)} do
      {_, []} -> result
      {[], acc} -> [result, acc]
      {_, acc} -> [result, delimiter, acc]
    end
  end

  defp join_values_to_iodata([], _) do
    []
  end

  # https://github.com/elixir-plug/plug/blob/master/lib/plug/html.ex
  @spec escape_to_iodata(binary(), integer(), binary(), iodata()) :: iodata()
  @spec escape_to_iodata(binary(), integer(), binary(), iodata(), integer()) :: iodata()
  for {match, insert} <- @escape_chars do
    defp escape_to_iodata(<<unquote(match), rest::bits>>, skip, original, acc) do
      escape_to_iodata(rest, skip + 1, original, [acc | unquote(insert)])
    end
  end

  defp escape_to_iodata(<<_char, rest::bits>>, skip, original, acc) do
    escape_to_iodata(rest, skip, original, acc, 1)
  end

  defp escape_to_iodata(<<>>, _skip, _original, acc) do
    acc
  end

  for {match, insert} <- @escape_chars do
    defp escape_to_iodata(<<unquote(match), rest::bits>>, skip, original, acc, len) do
      part = binary_part(original, skip, len)
      escape_to_iodata(rest, skip + len + 1, original, [acc, part | unquote(insert)])
    end
  end

  defp escape_to_iodata(<<_char, rest::bits>>, skip, original, acc, len) do
    escape_to_iodata(rest, skip, original, acc, len + 1)
  end

  defp escape_to_iodata(<<>>, 0, original, _acc, _len) do
    original
  end

  defp escape_to_iodata(<<>>, skip, original, acc, len) do
    [acc | binary_part(original, skip, len)]
  end
end
