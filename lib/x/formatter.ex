defmodule X.Formatter do
  alias Inspect.Algebra, as: A

  @script_tags ['script', 'style']

  def call(tree, options \\ []) do
    tree
    |> list_to_doc()
    |> A.nest(Keyword.get(options, :nest, 0))
    |> A.format(:infinity)
    |> IO.iodata_to_binary()
  end

  defp list_to_doc(list, delimiter) do
    list
    |> Enum.map(&format(&1))
    |> Enum.intersperse(delimiter)
    |> A.concat()
  end

  defp list_to_doc(list) when is_list(list) do
    list_to_doc(list, A.empty())
  end

  defp format({token = {:tag_start, _, _, _, _, _, is_singletone, _, _}, children}) do
    {tag_head_doc, is_multiple_attrs} = format_tag_head(token)
    tag_body_doc = format_tag_body(token, children, is_multiple_attrs)

    A.concat([
      A.line(),
      tag_head_doc,
      if(is_multiple_attrs, do: A.line(), else: A.empty()),
      if(is_singletone, do: ">", else: tag_body_doc)
    ])
  end

  defp format({{:text_group, _, _}, [{{:tag_text, _, _, _, true}, []}]}) do
    A.empty()
  end

  defp format({{:text_group, _, tag_name}, children}) do
    is_script = tag_name in @script_tags

    children
    |> Enum.reduce([], fn node, acc ->
      case node do
        {{:tag_text, _, [first | _], _, true}, []} ->
          case {acc, first} do
            {[:doc_line], ?\n} -> [A.line()]
            {[], ?\n} -> [A.line()]
            {[], _} -> [" "]
            {_, ?\s} -> [format(node) | acc]
            _ -> [A.line() | acc]
          end

        {{:tag_text, _, [?\n | _], _, _}, []} ->
          delimiter = if(is_script || acc == [:doc_line], do: A.empty(), else: A.line())
          result = if(is_script, do: format(node), else: String.trim_leading(format(node)))

          [result, delimiter | acc]

        _ ->
          [format(node) | acc]
      end
    end)
    |> Enum.reduce([], fn
      :doc_line, [] -> []
      doc, acc -> [doc | acc]
    end)
    |> A.concat()
  end

  defp format({{:tag_text, _, text, _, _}, _}) do
    to_string(text)
  end

  defp format({expr, _, value}) when expr in [:if, :elseif, :for, :unless] do
    ~s(x-#{expr}="#{format_code(value)}")
  end

  defp format({:else, _, _}) do
    "x-else"
  end

  defp format({{:tag_output, _, data, is_html_escape}, _}) do
    "{{#{unless(is_html_escape, do: "=")} #{format_code(data)} }}"
  end

  defp format({:tag_attr, _, name, value, is_dynamic}) do
    delimiter =
      case value do
        '%{' ++ _ -> ""
        [?{ | _] -> ""
        [?[ | _] -> ""
        [?" | _] -> "'"
        _ -> <<?">>
      end

    value = if(is_dynamic, do: format_code(value), else: value)

    "#{if(is_dynamic, do: ":")}#{name}=" <> delimiter <> to_string(value) <> delimiter
  end

  defp format_tag_head({:tag_start, _, name, attrs, condition, iterator, _, _, _}) do
    tag_attrs = sort_tag_attrs(condition, iterator, attrs)
    attrs_length = length(tag_attrs)
    is_multiple_attrs = attrs_length > 1

    attrs_doc = list_to_doc(tag_attrs, if(is_multiple_attrs, do: A.line()))

    tag_name_end =
      case attrs_length do
        0 -> A.empty()
        1 -> " "
        _ -> A.line()
      end

    doc =
      A.nest(
        A.concat([
          "<#{name}",
          tag_name_end,
          attrs_doc
        ]),
        2
      )

    {doc, is_multiple_attrs}
  end

  defp format_tag_body({:tag_start, _, name, _, _, _, _, _, _}, children, is_multiple_attrs) do
    is_selfclosed = length(children) == 0

    tag_head_end =
      cond do
        is_selfclosed && is_multiple_attrs -> A.empty()
        is_selfclosed -> " />"
        true -> ">"
      end

    tag_selfclose = if(is_multiple_attrs, do: "/>", else: A.empty())

    tag_close =
      A.concat(
        if(singleline?(children),
          do: A.empty(),
          else: A.line()
        ),
        "</#{name}>"
      )

    A.concat([
      A.nest(
        A.concat([
          tag_head_end,
          list_to_doc(children)
        ]),
        2
      ),
      if(is_selfclosed,
        do: tag_selfclose,
        else: tag_close
      )
    ])
  end

  defp format_code(string) do
    Code.format_string!(to_string(string))
  end

  defp sort_tag_attrs(condition, iterator, attrs) do
    attrs = Enum.sort_by(attrs, fn {:tag_attr, _, name, _, _} -> name end)

    {id_attrs, attrs} =
      Enum.split_with(attrs, fn {_, _, name, _, _} ->
        name == 'id'
      end)

    {dynamic_attrs, regular_attrs} =
      Enum.split_with(attrs, fn {_, _, _, _, is_dynamic} ->
        is_dynamic
      end)

    id_attrs
    |> Kernel.++([condition, iterator])
    |> Kernel.++(dynamic_attrs)
    |> Kernel.++(regular_attrs)
    |> Enum.filter(& &1)
  end

  defp singleline?(children) do
    case children do
      [{{:text_group, _, _}, nested}] ->
        Enum.all?(nested, fn
          {{:tag_text, _, [first | _], _, true}, []} ->
            first != ?\n

          _ ->
            true
        end)

      _ ->
        false
    end
  end
end
