defmodule X.Formatter do
  @moduledoc """
  X template formatted module.
  """

  alias X.Ast
  alias Inspect.Algebra, as: A

  @type options() :: [
          {:nest, integer()}
          | {:width, non_neg_integer() | :infinity}
        ]

  @script_tags ['script', 'style']

  @default_line_length 80

  @doc ~S"""
  Formats given X template AST and returns template string.

  Options:
    * `:nest` - adds N leading whitespaces to every line of the formatted template.
      0 by default.

  ## Example

      iex> X.Formatter.call(
      ...> [
      ...>   {{:tag_start, {1, 1}, 'div', [], nil, nil, false, false, false},
      ...>    [
      ...>      {{:tag_start, {6, 1}, 'span',
      ...>        [{:tag_attr, {12, 1}, 'class', 'test', false}], nil, nil, false, false,
      ...>        false},
      ...>       [
      ...>         {{:text_group, {25, 1}, 'span'},
      ...>          [{{:tag_output, {25, 1}, 'a ', true}, []}]}
      ...>       ]}
      ...>    ]}
      ...> ])
      ~s(
      <div>
        <span class="test">{{ a }}</span>
      </div>)
  """
  @spec call([Ast.leaf()], options()) :: String.t()
  def call(tree, options \\ []) do
    tree
    |> ast_to_doc()
    |> A.nest(Keyword.get(options, :nest, 0))
    |> A.format(Keyword.get(options, :width, @default_line_length))
    |> IO.iodata_to_binary()
  end

  @spec ast_to_doc([Ast.leaf()]) :: A.t()
  defp ast_to_doc(list) when is_list(list) do
    ast_to_doc(list, A.empty())
  end

  @spec ast_to_doc([Ast.leaf()], A.t() | String.t()) :: A.t()
  defp ast_to_doc(list, delimiter) do
    list
    |> Enum.map(&format(&1))
    |> Enum.intersperse(delimiter)
    |> A.concat()
  end

  @spec format(Ast.leaf()) :: A.t()
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
    children
    |> Enum.reduce([], fn node, acc ->
      case node do
        {{:tag_text, _, [first | _], _, true}, []} ->
          if first == ?\n,
            do: [A.line() | acc],
            else: [" " | acc]

        {{:tag_text, _, [?\n | _], _, _}, []} ->
          if tag_name in @script_tags,
            do: [format(node), A.empty() | acc],
            else: [String.trim_leading(format(node)), A.line() | acc]

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
    :unicode.characters_to_binary(text)
  end

  defp format({{:tag_comment, _, text}, _}) do
    A.concat([A.line(), "<!", :unicode.characters_to_binary(text), ">"])
  end

  defp format({expr, _, value}) when expr in [:if, :for, :unless] do
    A.concat(["x-", Atom.to_string(expr), "=\"", format_code(value), "\""])
  end

  defp format({:elseif, _, value}) do
    A.concat(["x-else-if", "=\"", format_code(value), "\""])
  end

  defp format({:else, _, _}) do
    "x-else"
  end

  defp format({{:tag_output, _, data, is_html_escape}, _}) do
    A.concat([
      "{{",
      if(is_html_escape, do: " ", else: "= "),
      format_code(data),
      " }}"
    ])
  end

  defp format({:tag_attr, _, name, value, is_dynamic}) do
    delimiter =
      case value do
        '%{' ++ _ -> ""
        [char | _] when char in '{[' -> ""
        _ -> if(Enum.any?(value, &(&1 == ?")), do: "'", else: "\"")
      end

    case value do
      '' ->
        to_string(name)

      _ ->
        A.concat([
          if(is_dynamic, do: ":", else: ""),
          to_string(name),
          "=",
          delimiter,
          if(is_dynamic, do: format_code(value), else: to_string(value)),
          delimiter
        ])
    end
  end

  @spec format_tag_head(Ast.tag_start()) :: {A.t(), boolean()}
  defp format_tag_head({:tag_start, _, name, attrs, condition, iterator, _, _, _}) do
    tag_attrs = sort_tag_attrs(condition, iterator, attrs)
    attrs_length = length(tag_attrs)
    is_multiple_attrs = attrs_length > 1

    attrs_doc = ast_to_doc(tag_attrs, if(is_multiple_attrs, do: A.line()))

    tag_name_end =
      case attrs_length do
        0 -> A.empty()
        1 -> " "
        _ -> A.line()
      end

    doc =
      A.nest(
        A.concat([
          "<",
          :unicode.characters_to_binary(name),
          tag_name_end,
          attrs_doc
        ]),
        2
      )

    {doc, is_multiple_attrs}
  end

  @spec format_tag_body(Ast.tag_start(), [Ast.leaf()], boolean()) :: A.t()
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
      A.concat([
        if(singleline_children?(children),
          do: A.empty(),
          else: A.line()
        ),
        "</",
        :unicode.characters_to_binary(name),
        ">"
      ])

    A.concat([
      A.nest(
        A.concat([
          tag_head_end,
          ast_to_doc(children)
        ]),
        2
      ),
      if(is_selfclosed,
        do: tag_selfclose,
        else: tag_close
      )
    ])
  end

  @spec format_code(charlist()) :: A.t()
  defp format_code(string) do
    string
    |> IO.iodata_to_binary()
    |> Code.Formatter.to_algebra!()
  end

  @spec sort_tag_attrs(Ast.tag_condition(), Ast.tag_iterator(), [Ast.tag_attr()]) :: [
          Ast.tag_attr() | Ast.tag_condition() | Ast.tag_iterator()
        ]
  defp sort_tag_attrs(condition, iterator, attrs) do
    attrs = Enum.sort_by(attrs, fn {:tag_attr, _, name, _, _} -> name end)

    {id_attrs, attrs} = Enum.split_with(attrs, fn {_, _, name, _, _} -> name == 'id' end)

    {dynamic_attrs, regular_attrs} =
      Enum.split_with(attrs, fn {_, _, _, _, is_dynamic} -> is_dynamic end)

    [condition, iterator]
    |> Enum.filter(& &1)
    |> Kernel.++(id_attrs)
    |> Kernel.++(dynamic_attrs)
    |> Kernel.++(regular_attrs)
  end

  @spec singleline_children?([Ast.leaf()]) :: boolean()
  defp singleline_children?([{{:text_group, _, _}, nested}]) do
    Enum.all?(nested, fn
      {{:tag_text, _, [first | _], _, true}, []} ->
        first != ?\n

      _ ->
        true
    end)
  end

  defp singleline_children?(_) do
    false
  end
end
