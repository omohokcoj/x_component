defmodule X.Compiler do
  @moduledoc """
  X template compiler module.
  """

  alias X.Ast

  import X.Transformer,
    only: [
      compact_ast: 1,
      transform_expresion: 3,
      transform_inline_component: 4
    ]

  @special_tag_name 'X'
  @assigns_key_name 'assigns'
  @component_key_name 'component'
  @is_key_name 'is'
  @attrs_key_name 'attrs'
  @special_attr_assigns ['style', 'class']

  @type options() :: [
          {:inline, boolean()}
          | {:context, atom()}
          | {:line, integer()}
        ]

  @doc ~S"""
  Compiles given X template AST into Elixir AST.

  ## Example

      iex> X.Compiler.call(
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
      [
        "<div><span class=\"test\">",
        {{:., [line: 1],
          [{:__aliases__, [line: 1, alias: false], [:X, :Html]}, :to_safe_iodata]},
         [line: 1], [{:a, [line: 1], nil}]},
        "</span></div>"
      ]
  """
  @spec call([Ast.leaf()]) :: Macro.t()
  @spec call([Ast.leaf()], Macro.Env.t()) :: Macro.t()
  @spec call([Ast.leaf()], Macro.Env.t(), options()) :: Macro.t()
  def call(tree, env \\ __ENV__, opts \\ []) when is_map(env) do
    tree
    |> Ast.drop_whitespace()
    |> compile_tree(env, opts)
    |> compact_ast()
  end

  @spec compile_tree([Ast.leaf()], Macro.Env.t(), options()) :: Macro.t()
  defp compile_tree(tree = [head | _], env, opts) do
    {result, tail} =
      head
      |> compile(env, opts)
      |> maybe_wrap_in_iterator(head, env, opts)
      |> maybe_wrap_in_condition(tree, env, opts)

    [result | compile_tree(tail, env, opts)]
  end

  defp compile_tree([], _env, _opts) do
    []
  end

  defp compile({{:text_group, _, _}, list}, env, opts) do
    compile_text_group(list, env, opts, [])
  end

  defp compile({{:tag_output, cur = {_, row}, body, true}, _}, env, opts) do
    quote line: row + Keyword.get(opts, :line, 0) do
      X.Html.to_safe_iodata(unquote(compile_expr(body, cur, env, opts)))
    end
  end

  defp compile({{:tag_output, cur = {_, row}, body, false}, _}, env, opts) do
    quote line: row + Keyword.get(opts, :line, 0) do
      unquote(compile_expr(body, cur, env, opts))
    end
  end

  defp compile({{:tag_text, _, body, _, false}, _}, _env, _opts) do
    :unicode.characters_to_binary(body)
  end

  defp compile({{:tag_start, _, tag_name, attrs, _, _, false, _, false}, children}, env, opts) do
    tag_name_binary = :erlang.iolist_to_binary(tag_name)
    attrs_ast = compile_attrs(attrs, env, opts)
    children_ast = compile_tree(children, env, opts)

    [?<, tag_name_binary, attrs_ast, ?>, children_ast, "</", tag_name_binary, ?>]
  end

  defp compile({{:tag_start, _, tag_name, attrs, _, _, true, _, false}, _}, env, opts) do
    [?<, :erlang.iolist_to_binary(tag_name), compile_attrs(attrs, env, opts), ?>]
  end

  defp compile(
         {{:tag_start, cur, @special_tag_name, attrs, _, _, _, _, true}, children},
         env,
         opts
       ) do
    {component, is_tag, attrs} =
      Enum.reduce(attrs, {nil, nil, []}, fn
        {:tag_attr, _, @component_key_name, value, true}, {_, is_tag, acc} -> {value, is_tag, acc}
        {:tag_attr, _, @is_key_name, value, true}, {component, _, acc} -> {component, value, acc}
        attr, {component, is_tag, acc} -> {component, is_tag, [attr | acc]}
      end)

    cond do
      component ->
        compile_component(component, attrs, children, cur, env, opts)

      is_tag ->
        children_ast = compile_tree(children, env, opts)

        tag_ast = compile_expr(is_tag, cur, env, opts)
        attrs_ast = compile_attrs(:lists.reverse(attrs), env, opts)
        tag_ast = quote(do: :erlang.iolist_to_binary(unquote(tag_ast)))

        [?<, tag_ast, attrs_ast, ?>, children_ast, "</", tag_ast, ?>]

      true ->
        children
        |> Ast.drop_whitespace()
        |> compile_tree(env, opts)
    end
  end

  defp compile({{:tag_start, cur, tag_name, attrs, _, _, _, _, true}, children}, env, opts) do
    compile_component(tag_name, attrs, children, cur, env, opts)
  end

  defp compile({{:tag_comment, _, body}, _}, _env, _opts) do
    ["<!", :unicode.characters_to_binary(body), ?>]
  end

  @spec maybe_wrap_in_iterator(Macro.t(), Ast.leaf(), Macro.Env.t(), options()) :: Macro.t()
  defp maybe_wrap_in_iterator(ast, node, env, opts) do
    case node do
      {{:tag_start, _, _, _, _, iterator = {:for, _, _}, _, _, _}, _} ->
        compile_for_expr(iterator, ast, env, opts)

      _ ->
        ast
    end
  end

  @spec maybe_wrap_in_condition(Macro.t(), [Ast.leaf()], Macro.Env.t(), options()) :: Macro.t()
  defp maybe_wrap_in_condition(ast, [head | tail], env, opts) do
    case head do
      {{:tag_start, _, _, _, token = {condition, _, _}, _, _, _, _}, _}
      when condition in [:if, :unless] ->
        compile_cond_expr(token, ast, tail, env, opts)

      _ ->
        {ast, tail}
    end
  end

  @spec compile_attrs([Ast.tag_attr()], Macro.Env.t(), options()) :: [Macro.t()]
  defp compile_attrs(attrs, env, opts) do
    {attrs_ast, base_attrs, merge_attrs, static_attr_tokens} =
      group_and_transform_tag_attrs(attrs, env, opts)

    static_attrs_ast = Enum.map(static_attr_tokens, &compile_attr(&1, env, opts))

    case {attrs_ast, merge_attrs} do
      {nil, []} ->
        static_attrs_ast

      {nil, _} ->
        base_attrs = X.Html.merge_attrs(base_attrs, merge_attrs)

        [
          ?\s,
          quote do
            X.Html.attrs_to_iodata(unquote(base_attrs))
          end
          | static_attrs_ast
        ]

      _ ->
        static_attrs = Enum.map(static_attr_tokens, &attr_token_to_tuple(&1, env, opts))
        base_attrs = X.Html.merge_attrs(base_attrs, merge_attrs)

        quote do
          case unquote({:{}, [], [attrs_ast, base_attrs, static_attrs]}) do
            {attrs_, base_attrs_, static_attrs_}
            when attrs_ not in [nil, []] or base_attrs_ != [] ->
              [
                ?\s,
                X.Html.attrs_to_iodata(X.Html.merge_attrs(base_attrs_ ++ static_attrs_, attrs_))
              ]

            _ ->
              unquote(static_attrs_ast)
          end
        end
    end
  end

  @spec compile_attr(Ast.tag_attr(), Macro.Env.t(), options()) :: Macro.t()
  defp compile_attr({:tag_attr, cur, name, value, true}, env, opts) do
    name_string = :erlang.iolist_to_binary(name)

    quote do
      case unquote(compile_expr(value, cur, env, opts)) do
        true ->
          unquote(" " <> name_string <> "=\"true\"")

        value when value not in [nil, false] ->
          [
            unquote(" " <> name_string <> "=\""),
            X.Html.attr_value_to_iodata(
              value,
              unquote(name_string)
            ),
            ?"
          ]

        _ ->
          []
      end
    end
  end

  defp compile_attr({:tag_attr, _cur, name, [], false}, _env, _opts) do
    [?\s, :erlang.iolist_to_binary(name)]
  end

  defp compile_attr({:tag_attr, _cur, name, value, false}, _env, _opts) do
    [?\s, :erlang.iolist_to_binary(name), ?=, ?", :unicode.characters_to_binary(value), ?"]
  end

  @spec compile_assigns([Ast.tag_attr()], Macro.Env.t(), options()) :: Macro.t()
  defp compile_assigns(attrs, env, opts) do
    {assigns, attrs, assigns_list, attrs_list, merge_attrs} =
      group_and_transform_component_attrs(attrs, env, opts)

    merged_attrs =
      case {attrs_list, merge_attrs} do
        {[], _} -> []
        {_, []} -> attrs_list
        {_, _} -> quote(do: X.Html.merge_attrs(unquote(attrs_list), unquote(merge_attrs)))
      end

    attrs_ast =
      case {attrs, merged_attrs} do
        {nil, []} -> nil
        {nil, _} -> merged_attrs
        {_, []} -> attrs
        {_, _} -> quote(do: X.Html.merge_attrs(unquote(merged_attrs), unquote(attrs)))
      end

    case {assigns, attrs_ast} do
      {nil, nil} -> {:%{}, [], assigns_list}
      {nil, _} -> {:%{}, [], [{:attrs, attrs_ast} | assigns_list]}
      {_, nil} -> assigns
      {_, _} -> quote(do: Map.put(unquote(assigns), :attrs, unquote(attrs_ast)))
    end
  end

  @spec compile_cond_expr(
          Ast.tag_condition(),
          Macro.t(),
          [Ast.leaf()],
          Macro.Env.t(),
          options()
        ) ::
          {Macro.t(), [Ast.leaf()]}
  defp compile_cond_expr({:unless, cur, expr}, ast, tail, env, opts) do
    compile_cond_expr({:if, cur, '!(' ++ expr ++ ')'}, ast, tail, env, opts)
  end

  defp compile_cond_expr(condition = {:if, cur = {_, row}, expr}, ast, tail, env, opts) do
    {else_ast, tail} = find_cond_else_expr(condition, ast, tail, env, opts)

    ast =
      quote line: row + Keyword.get(opts, :line, 0) do
        if(unquote(compile_expr(expr, cur, env, opts)),
          do: unquote(compact_ast(ast)),
          else: unquote(compact_ast(else_ast))
        )
      end

    {ast, tail}
  end

  @spec find_cond_else_expr(
          Ast.tag_condition(),
          Macro.t(),
          [Ast.leaf()],
          Macro.Env.t(),
          options()
        ) ::
          {Macro.t(), [Ast.leaf()]}
  defp find_cond_else_expr(condition, ast, tail, env, opts) do
    case tail do
      [next = {{:tag_start, _, _, _, {:else, _cur, _}, _, _, _, _}, _} | rest] ->
        {compile(next, env, opts), rest}

      [next = {{:tag_start, _, _, _, {:elseif, cur, expr}, _, _, _, _}, _} | rest] ->
        compile_cond_expr({:if, cur, expr}, compile(next, env, opts), rest, env, opts)

      [{{:text_group, _, _}, [{{:tag_text, _, _, _, true}, _}]} | rest] ->
        find_cond_else_expr(condition, ast, rest, env, opts)

      _ ->
        {[], tail}
    end
  end

  @spec compile_for_expr(Ast.tag_iterator(), Macro.t(), Macro.Env.t(), options()) :: Macro.t()
  defp compile_for_expr({:for, cur = {_, row}, expr}, ast, env, opts) do
    expr =
      case expr do
        '[' ++ _ -> expr
        _ -> [?[ | expr] ++ ']'
      end

    quote line: row + Keyword.get(opts, :line, 0) do
      for(unquote_splicing(compile_expr(expr, cur, env, opts)),
        do: unquote(compact_ast(ast)),
        into: []
      )
    end
  end

  @spec compile_expr(charlist(), Ast.cursor(), Macro.Env.t(), options()) :: Macro.t()
  defp compile_expr(charlist, {_, row}, env, opts) do
    quoted = Code.string_to_quoted!(charlist, line: row + Keyword.get(opts, :line, 0))

    transform_expresion(quoted, Keyword.get(opts, :context), env)
  end

  @spec compile_component(
          charlist(),
          [Ast.tag_attr()],
          [Ast.leaf()],
          Ast.cursor(),
          Macro.Env.t(),
          options()
        ) ::
          Macro.t()
  defp compile_component(component, attrs, children, cur = {_, row}, env, opts) do
    component_ast = compile_expr(component, cur, env, opts)
    assigns_ast = compile_assigns(attrs, env, opts)
    line = row + Keyword.get(opts, :line, 0)

    assigns_list =
      case assigns_ast do
        {:%{}, _, assigns_list} -> assigns_list
        _ -> nil
      end

    if Keyword.get(opts, :inline, true) &&
         !is_nil(assigns_list) &&
         is_atom(component_ast) &&
         Code.ensure_compiled?(component_ast) &&
         function_exported?(component_ast, :template_ast, 0) do
      children_ast = children |> Ast.drop_whitespace() |> compile_tree(env, opts)

      quote line: line do
        unquote(transform_inline_component(component_ast, assigns_list, children_ast, line))
      end
    else
      children_ast = call(children, env, opts)

      args_ast =
        case children do
          [] -> [assigns_ast]
          _ -> [assigns_ast, [do: children_ast]]
        end

      quote line: line do
        unquote(component_ast).render(unquote_splicing(args_ast))
      end
    end
  end

  @spec compile_text_group([Ast.token()], Macro.Env.t(), options(), list()) :: [Macro.t()]

  defp compile_text_group([{{:tag_text, _, _, _, true}, _} | tail], env, opts, acc = [" " | _]) do
    compile_text_group(tail, env, opts, acc)
  end

  defp compile_text_group([head | tail], env, opts, acc) do
    result =
      case head do
        {{:tag_text, _, _, _, true}, _} ->
          " "

        {{:tag_text, _, [char | _], true, _}, _} ->
          result = String.trim_leading(compile(head, env, opts))

          case char do
            ?\n -> "\n" <> result
            _ -> " " <> result
          end

        head ->
          compile(head, env, opts)
      end

    compile_text_group(tail, env, opts, [result | acc])
  end

  defp compile_text_group([], _, _opts, acc) do
    :lists.reverse(acc)
  end

  @spec group_and_transform_tag_attrs([Ast.tag_attr()], Macro.Env.t(), options()) :: {
          attrs_ast :: Macro.t() | nil,
          base_attrs :: [{binary(), Macro.t()}],
          merge_attrs :: [{binary(), Macro.t()}],
          static_attrs :: [Ast.tag_attr()]
        }
  defp group_and_transform_tag_attrs(attrs, env, opts) do
    Enum.reduce(attrs, {nil, [], [], []}, fn attr_token,
                                             {attr_ast, base_attrs, merge_attrs,
                                              static_attr_tokens} ->
      case attr_token do
        {_, cur, @attrs_key_name, value, true} ->
          {compile_expr(value, cur, env, opts), base_attrs, merge_attrs, static_attr_tokens}

        {_, _, name, _, is_dynamic} ->
          case List.keytake(static_attr_tokens, name, 2) do
            {m_attr_token = {:tag_attr, _, _, _, true}, rest_attrs} when is_dynamic == false ->
              {
                attr_ast,
                [attr_token_to_tuple(m_attr_token, env, opts) | base_attrs],
                [attr_token_to_tuple(attr_token, env, opts) | merge_attrs],
                rest_attrs
              }

            {m_attr_token = {:tag_attr, _, _, _, false}, rest_attrs} when is_dynamic == true ->
              {
                attr_ast,
                [attr_token_to_tuple(attr_token, env, opts) | base_attrs],
                [attr_token_to_tuple(m_attr_token, env, opts) | merge_attrs],
                rest_attrs
              }

            nil ->
              {attr_ast, base_attrs, merge_attrs, [attr_token | static_attr_tokens]}
          end
      end
    end)
  end

  @spec group_and_transform_component_attrs([Ast.tag_attr()], Macro.Env.t(), options()) :: {
          attrs_ast :: Macro.t() | nil,
          assigns_ast :: Macro.t() | nil,
          assigns_list :: [{binary(), Macro.t()}],
          attrs_list :: [{binary(), Macro.t()}],
          merge_attrs_list :: [Ast.tag_attr()]
        }
  def group_and_transform_component_attrs(attrs, env, opts) do
    Enum.reduce(attrs, {nil, nil, [], [], []}, fn token = {_, cur, name, value, is_dynamic},
                                                  {assigns, attrs, assigns_acc, attrs_acc,
                                                   merge_acc} ->
      if is_dynamic && name not in @special_attr_assigns do
        value = compile_expr(value, cur, env, opts)

        case name do
          @assigns_key_name ->
            {value, attrs, assigns_acc, attrs_acc, merge_acc}

          @attrs_key_name ->
            {assigns, value, assigns_acc, attrs_acc, merge_acc}

          _ ->
            {assigns, attrs, [{attr_key_to_atom(name), value} | assigns_acc], attrs_acc,
             merge_acc}
        end
      else
        case List.keytake(attrs_acc, to_string(name), 0) do
          {attr = {_, value}, rest_attrs} when is_binary(value) ->
            {assigns, attrs, assigns_acc, [attr | rest_attrs],
             [attr_token_to_tuple(token, env, opts) | merge_acc]}

          {attr, rest_attrs} ->
            {assigns, attrs, assigns_acc, [attr_token_to_tuple(token, env, opts) | rest_attrs],
             [attr | merge_acc]}

          nil ->
            {assigns, attrs, assigns_acc, [attr_token_to_tuple(token, env, opts) | attrs_acc],
             merge_acc}
        end
      end
    end)
  end

  @spec attr_token_to_tuple(Ast.tag_attr(), Macro.Env.t(), options()) :: {String.t(), Macro.t()}
  defp attr_token_to_tuple(token, env, opts) do
    case token do
      {:tag_attr, _cur, name, value, false} ->
        {:erlang.iolist_to_binary(name), :unicode.characters_to_binary(value)}

      {:tag_attr, cur, name, value, true} ->
        {:erlang.iolist_to_binary(name), compile_expr(value, cur, env, opts)}
    end
  end

  @spec attr_key_to_atom(charlist()) :: atom()
  defp attr_key_to_atom(name) do
    String.to_atom(
      for(
        char <- name,
        do:
          case char do
            ?- -> "_"
            _ -> <<char>>
          end,
        into: <<>>
      )
    )
  end
end
