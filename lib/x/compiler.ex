defmodule X.Compiler do
  alias X.Ast
  alias X.Html

  @special_tag_name 'X'
  @assigns_key_name 'assigns'
  @component_key_name 'component'
  @is_key_name 'is'
  @attrs_key_name 'attrs'
  @special_attr_assigns ['style', 'class']

  @type env() :: X.Template.env()

  @spec call([Ast.leaf()]) :: Macro.t()
  @spec call([Ast.leaf()], env()) :: Macro.t()
  def call(tree, env \\ []) do
    tree
    |> compile_tree(env)
    |> transform_ast()
  end

  @spec compile_tree([Ast.leaf()], env()) :: Macro.t()
  defp compile_tree(tree = [head | _], env) do
    {result, tail} =
      head
      |> compile(env)
      |> maybe_wrap_in_iterator(head, env)
      |> maybe_wrap_in_condition(tree, env)

    [result | compile_tree(tail, env)]
  end

  defp compile_tree([], _env) do
    []
  end

  @spec transform_ast(Macro.t()) :: Macro.t()
  defp transform_ast(tree) when is_list(tree) do
    tree
    |> List.flatten()
    |> join_binary()
  end

  defp transform_ast(tree) do
    tree
  end

  @spec compile(Ast.leaf(), env()) :: Macro.t()
  defp compile({{:text_group, _, _}, list}, env) do
    compile_text_group(list, env)
  end

  defp compile({{:tag_output, cur, body, true}, _}, env) do
    quote do
      Html.to_safe_iodata(unquote(compile_expr(body, cur, env)))
    end
  end

  defp compile({{:tag_output, cur, body, false}, _}, env) do
    quote do
      to_string(unquote(compile_expr(body, cur, env)))
    end
  end

  defp compile({{:tag_text, _, body, _, false}, _}, _env) do
    :unicode.characters_to_binary(body)
  end

  defp compile({{:tag_start, _, tag_name, attrs, _, _, false, _, false}, children}, env) do
    tag_name_binary = :erlang.iolist_to_binary(tag_name)
    attrs_ast = compile_attrs(attrs, env)
    children_ast = compile_tree(children, env)

    [?<, tag_name_binary, attrs_ast, ?>, children_ast, "</", tag_name_binary, ?>]
  end

  defp compile({{:tag_start, _, tag_name, attrs, _, _, true, _, false}, _}, env) do
    [?<, :erlang.iolist_to_binary(tag_name), compile_attrs(attrs, env), ?>]
  end

  defp compile({{:tag_start, cur, @special_tag_name, attrs, _, _, _, _, true}, children}, env) do
    {component, is_tag, attrs} =
      Enum.reduce(attrs, {nil, nil, []}, fn
        {:tag_attr, _, @component_key_name, value, true}, {_, is_tag, acc} -> {value, is_tag, acc}
        {:tag_attr, _, @is_key_name, value, true}, {component, _, acc} -> {component, value, acc}
        attr, {component, is_tag, acc} -> {component, is_tag, [attr | acc]}
      end)

    children_ast = compile_tree(children, env)

    cond do
      component ->
        compile_component(component, attrs, children, cur, env)

      is_tag ->
        tag_ast = compile_expr(is_tag, cur, env)
        attrs_ast = compile_attrs(Enum.reverse(attrs), env)
        tag_ast = quote(do: :erlang.iolist_to_binary(unquote(tag_ast)))

        [?<, tag_ast, attrs_ast, ?>, children_ast, "</", tag_ast, ?>]

      true ->
        children_ast
    end
  end

  defp compile({{:tag_start, cur, tag_name, attrs, _, _, _, _, true}, children}, env) do
    compile_component(tag_name, attrs, children, cur, env)
  end

  defp compile({{:tag_comment, _, body}, _}, _env) do
    ["<!", :unicode.characters_to_binary(body), ?>]
  end

  @spec maybe_wrap_in_iterator(Macro.t(), Ast.leaf(), env()) :: Macro.t()
  defp maybe_wrap_in_iterator(ast, node, env) do
    case node do
      {{:tag_start, _, _, _, _, iterator = {:for, _, _}, _, _, _}, _} ->
        compile_for_expr(iterator, ast, env)

      _ ->
        ast
    end
  end

  @spec maybe_wrap_in_condition(Macro.t(), [Ast.leaf()], env()) :: Macro.t()
  defp maybe_wrap_in_condition(ast, [head | tail], env) do
    case head do
      {{:tag_start, _, _, _, token = {condition, _, _}, _, _, _, _}, _}
      when condition in [:if, :unless] ->
        compile_cond_expr(token, ast, tail, env)

      _ ->
        {ast, tail}
    end
  end

  @spec compile_attrs([Ast.tag_attr()], env()) :: [Macro.t()]
  defp compile_attrs(attrs, env) do
    {attrs_ast, base_attrs, merge_attrs, static_attr_tokens} =
      group_and_transform_tag_attrs(attrs, env)

    case {attrs_ast, merge_attrs} do
      {nil, []} ->
        Enum.map(static_attr_tokens, &compile_attr(&1, env))

      {nil, _} ->
        [
          ?\s,
          quote do
            Html.attrs_to_iodata(Html.merge_attrs(unquote(base_attrs), unquote(merge_attrs)))
          end
          | Enum.map(static_attr_tokens, &compile_attr(&1, env))
        ]

      _ ->
        quote do
          case {unquote(attrs_ast), unquote(base_attrs)} do
            {attrs, base_attrs} when attrs not in [nil, []] or base_attrs != [] ->
              [
                ?\s,
                Html.attrs_to_iodata(
                  Html.merge_attrs(
                    Html.merge_attrs(base_attrs, unquote(merge_attrs)) ++
                      unquote(Enum.map(static_attr_tokens, &attr_token_to_tuple(&1, env))),
                    attrs
                  )
                )
              ]

            _ ->
              unquote(Enum.map(static_attr_tokens, &compile_attr(&1, env)))
          end
        end
    end
  end

  @spec compile_attrs(Ast.tag_attr(), env()) :: Macro.t()
  defp compile_attr({:tag_attr, cur, name, value, true}, env) do
    name_string = :erlang.iolist_to_binary(name)

    value_ast =
      quote do
        Html.attr_value_to_iodata(unquote(compile_expr(value, cur, env)), unquote(name_string))
      end

    [?\s, name_string, ?=, ?", value_ast, ?"]
  end

  defp compile_attr({:tag_attr, _cur, name, [], false}, _) do
    [?\s, :erlang.iolist_to_binary(name)]
  end

  defp compile_attr({:tag_attr, _cur, name, value, false}, _) do
    [?\s, :erlang.iolist_to_binary(name), ?=, ?", :unicode.characters_to_binary(value), ?"]
  end

  @spec compile_assigns([Ast.tag_attr()], env()) :: Macro.t()
  defp compile_assigns(attrs, env) do
    {assigns, attrs, assigns_list, attrs_list, merge_attrs} =
      group_and_transform_component_attrs(attrs, env)

    merged_attrs =
      case {attrs_list, merge_attrs} do
        {[], _} -> []
        {_, []} -> attrs_list
        {_, _} -> quote(do: Html.merge_attrs(unquote(attrs_list), unquote(merge_attrs)))
      end

    attrs_ast =
      case {attrs, merged_attrs} do
        {nil, []} -> nil
        {nil, _} -> merged_attrs
        {_, []} -> attrs
        {_, _} -> quote(do: Html.merge_attrs(unquote(merged_attrs), unquote(attrs)))
      end

    case {assigns, attrs_ast} do
      {nil, nil} -> {:%{}, [], assigns_list}
      {nil, _} -> {:%{}, [], [{:attrs, attrs_ast} | assigns_list]}
      {_, nil} -> assigns
      {_, _} -> quote(do: Map.put(unquote(assigns), :attrs, unquote(attrs_ast)))
    end
  end

  @spec compile_cond_expr(Ast.tag_condition(), Macro.t(), [Ast.leaf()], env()) ::
          {Macro.t(), [Ast.leaf()]}
  defp compile_cond_expr({:unless, cur, expr}, ast, tail, env) do
    compile_cond_expr({:if, cur, '!(' ++ expr ++ ')'}, ast, tail, env)
  end

  defp compile_cond_expr(condition = {:if, cur, expr}, ast, tail, env) do
    {else_ast, tail} = find_cond_else_expr(condition, ast, tail, env)

    ast =
      quote do
        if(unquote(compile_expr(expr, cur, env)),
          do: unquote(transform_ast(ast)),
          else: unquote(transform_ast(else_ast))
        )
      end

    {ast, tail}
  end

  @spec find_cond_else_expr(Ast.tag_condition(), Macro.t(), [Ast.leaf()], env()) ::
          {Macro.t(), [Ast.leaf()]}
  defp find_cond_else_expr(condition, ast, tail, env) do
    case tail do
      [next = {{:tag_start, _, _, _, {:else, _cur, _}, _, _, _, _}, _} | rest] ->
        {compile(next, env), rest}

      [next = {{:tag_start, _, _, _, {:elseif, cur, expr}, _, _, _, _}, _} | rest] ->
        compile_cond_expr({:if, cur, expr}, compile(next, env), rest, env)

      [{{:text_group, _, _}, [{{:tag_text, _, _, _, true}, _}]} | rest] ->
        find_cond_else_expr(condition, ast, rest, env)

      _ ->
        {[], tail}
    end
  end

  @spec compile_for_expr(Ast.tag_iterator(), Macro.t(), env()) :: Macro.t()
  defp compile_for_expr({:for, cur, expr}, ast, env) do
    expr =
      case expr do
        '[' ++ expr -> expr
        _ -> [?[ | expr] ++ ']'
      end

    quote do
      for(unquote_splicing(compile_expr(expr, cur, env)),
        do: unquote(transform_ast(ast)),
        into: []
      )
    end
  end

  @spec compile_expr(charlist(), Ast.cursor(), env()) :: Macro.t()
  defp compile_expr(charlist, {_, row}, env) do
    quoted = Code.string_to_quoted!(charlist, line: row + Keyword.get(env, :line, 0))

    Macro.postwalk(quoted, fn
      {:@, meta, [{name, _, atom}]} when is_atom(name) and is_atom(atom) ->
        line = Keyword.get(meta, :line, 0)

        case name do
          :assigns -> quote(line: line, do: var!(assigns))
          :yield -> quote(line: line, do: var!(yield))
          _ -> quote(line: line, do: Map.get(var!(assigns), unquote(name)))
        end

      a ->
        a
    end)
  end

  @spec compile_component(charlist(), [Ast.tag_attr()], [Ast.leaf()], Ast.cursor(), env()) ::
          Macro.t()
  defp compile_component(component, attrs, children, {row, col}, env) do
    component_ast = compile_expr(component, {row, col}, env)

    assigns_ast = compile_assigns(attrs, env)

    render_args_ast =
      case children do
        [] -> [assigns_ast]
        _ -> [assigns_ast, [do: call(children, env)]]
      end

    quote line: row + Keyword.get(env, :line, 0) do
      unquote(component_ast).render(unquote_splicing(render_args_ast))
    end
  end

  @spec compile_text_group([Ast.token()], env()) :: [Macro.t()]
  defp compile_text_group(tokens, env) do
    compile_text_group(tokens, env, [])
  end

  @spec compile_text_group([Ast.token()], env(), list()) :: [Macro.t()]
  defp compile_text_group([{{:tag_text, _, _, _, true}, _} | tail], env, acc = [" " | _]) do
    compile_text_group(tail, env, acc)
  end

  defp compile_text_group([head | tail], env, acc) do
    result =
      case head do
        {{:tag_text, _, _, _, true}, _} ->
          " "

        {{:tag_text, _, [char | _], true, _}, _} ->
          result = String.trim_leading(compile(head, env))

          case char do
            ?\n -> "\n" <> result
            _ -> " " <> result
          end

        head ->
          compile(head, env)
      end

    compile_text_group(tail, env, [result | acc])
  end

  defp compile_text_group([], _, acc) do
    Enum.reverse(acc)
  end

  @spec group_and_transform_tag_attrs([Ast.tag_attr()], env()) :: {
          attrs_ast :: Macro.t() | nil,
          base_attrs :: [{binary(), Macro.t()}],
          merge_attrs :: [{binary(), Macro.t()}],
          static_attrs :: [Ast.tag_attr()]
        }
  defp group_and_transform_tag_attrs(attrs, env) do
    Enum.reduce(attrs, {nil, [], [], []}, fn attr_token,
                                             {attr_ast, base_attrs, merge_attrs,
                                              static_attr_tokens} ->
      case attr_token do
        {_, cur, @attrs_key_name, value, true} ->
          {compile_expr(value, cur, env), base_attrs, merge_attrs, static_attr_tokens}

        {_, _, name, _, is_dynamic} ->
          case List.keytake(static_attr_tokens, name, 2) do
            {m_attr_token = {:tag_attr, _, _, _, true}, rest_attrs} when is_dynamic == false ->
              {
                attr_ast,
                [attr_token_to_tuple(m_attr_token, env) | base_attrs],
                [attr_token_to_tuple(attr_token, env) | merge_attrs],
                rest_attrs
              }

            {m_attr_token = {:tag_attr, _, _, _, false}, rest_attrs} when is_dynamic == true ->
              {
                attr_ast,
                [attr_token_to_tuple(attr_token, env) | base_attrs],
                [attr_token_to_tuple(m_attr_token, env) | merge_attrs],
                rest_attrs
              }

            nil ->
              {attr_ast, base_attrs, merge_attrs, [attr_token | static_attr_tokens]}
          end
      end
    end)
  end

  @spec group_and_transform_component_attrs([Ast.tag_attr()], env()) :: {
          attrs_ast :: Macro.t() | nil,
          assigns_ast :: Macro.t() | nil,
          assigns_list :: [{binary(), Macro.t()}],
          attrs_list :: [{binary(), Macro.t()}],
          merge_attrs_list :: [Ast.tag_attr()]
        }
  def group_and_transform_component_attrs(attrs, env) do
    Enum.reduce(attrs, {nil, nil, [], [], []}, fn token = {_, cur, name, value, is_dynamic},
                                                  {assigns, attrs, assigns_acc, attrs_acc,
                                                   merge_acc} ->
      if is_dynamic && name not in @special_attr_assigns do
        value = compile_expr(value, cur, env)

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
             [attr_token_to_tuple(token, env) | merge_acc]}

          {attr, rest_attrs} ->
            {assigns, attrs, assigns_acc, [attr_token_to_tuple(token, env) | rest_attrs],
             [attr | merge_acc]}

          nil ->
            {assigns, attrs, assigns_acc, [attr_token_to_tuple(token, env) | attrs_acc],
             merge_acc}
        end
      end
    end)
  end

  @spec attr_token_to_tuple(Ast.tag_attr(), env()) :: {String.t(), Macro.t()}
  defp attr_token_to_tuple(token, env) do
    case token do
      {:tag_attr, _cur, name, value, false} ->
        {:erlang.iolist_to_binary(name), :unicode.characters_to_binary(value)}

      {:tag_attr, cur, name, value, true} ->
        {:erlang.iolist_to_binary(name), compile_expr(value, cur, env)}
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

  @spec join_binary(Macro.t(), list(), list()) :: Macro.t()
  defp join_binary(list, iodata \\ [], acc \\ [])

  defp join_binary([ast = {_, _, _} | tail], iodata, acc) do
    join_binary(tail, [], [ast, IO.iodata_to_binary(iodata) | acc])
  end

  defp join_binary([head | tail], iodata, acc) do
    join_binary(tail, [iodata, head], acc)
  end

  defp join_binary([], iodata, []) do
    IO.iodata_to_binary(iodata)
  end

  defp join_binary([], iodata, acc) do
    Enum.reverse([IO.iodata_to_binary(iodata) | acc])
  end
end
