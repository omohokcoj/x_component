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
  def call(tree) do
    call(tree, [], [])
  end

  @spec call([Ast.leaf()], env()) :: Macro.t()
  def call(tree, env) do
    call(tree, env, [])
  end

  @spec call([Ast.leaf()], env(), [Macro.t()]) :: Macro.t()
  def call(tree = [head | _], env, acc) do
    {result, tail} =
      head
      |> compile(env)
      |> maybe_wrap_in_iterator(head, env)
      |> maybe_wrap_in_condition(tree, env)

    call(tail, env, [result | acc])
  end

  def call([], _env, acc) do
    quote do
      <<unquote_splicing(reverse_map_binary_ast(acc))>>
    end
  end

  @spec compile(Ast.leaf(), env()) :: Macro.t()
  defp compile(node = {{:text_group, _, _}, _}, env) do
    quote do
      <<unquote_splicing(compile_text_group(node, env))>>
    end
  end

  defp compile({{:tag_output, cur, body, true}, _}, env) do
    quote do
      Html.to_safe_string(unquote(compile_expr(body, cur, env)))
    end
  end

  defp compile({{:tag_output, cur, body, false}, _}, env) do
    quote do
      Kernel.to_string(unquote(compile_expr(body, cur, env)))
    end
  end

  defp compile({{:tag_text, _, body, _, false}, _}, _env) do
    :unicode.characters_to_binary(body)
  end

  defp compile({{:tag_start, _, tag_name, attrs, _, _, false, _, false}, children}, env) do
    tag_name_binary = :erlang.iolist_to_binary(tag_name)

    quote do
      <<
        ?<,
        unquote(tag_name_binary),
        unquote_splicing(compile_attrs(attrs, env)),
        ?>,
        unquote(call(children, env)),
        "</",
        unquote(tag_name_binary),
        ?>
      >>
    end
  end

  defp compile({{:tag_start, _, tag_name, attrs, _, _, true, _, false}, _}, env) do
    quote do
      <<
        ?<,
        unquote(:erlang.iolist_to_binary(tag_name)),
        unquote_splicing(compile_attrs(attrs, env)),
        ?>
      >>
    end
  end

  defp compile({{:tag_start, cur, @special_tag_name, attrs, _, _, _, _, true}, children}, env) do
    {component, is_tag, attrs} =
      Enum.reduce(attrs, {nil, nil, []}, fn
        {:tag_attr, _, @component_key_name, value, true}, {_, is_tag, acc} -> {value, is_tag, acc}
        {:tag_attr, _, @is_key_name, value, true}, {component, _, acc} -> {component, value, acc}
        attr, {component, is_tag, acc} -> {component, is_tag, [attr | acc]}
      end)

    children_ast = call(children, env)

    cond do
      component ->
        compile_component(component, attrs, children, cur, env)

      is_tag ->
        tag_ast = compile_expr(is_tag, cur, env)
        attrs_ast = compile_attrs(Enum.reverse(attrs), env)
        tag_ast = quote(do: :erlang.iolist_to_binary(unquote(tag_ast)))

        quote do
          <<?<, unquote(tag_ast)::binary, unquote_splicing(attrs_ast), ?>, unquote(children_ast),
            "</", unquote(tag_ast)::binary, ?>>>
        end

      true ->
        children_ast
    end
  end

  defp compile({{:tag_start, cur, tag_name, attrs, _, _, _, _, true}, children}, env) do
    compile_component(tag_name, attrs, children, cur, env)
  end

  defp compile({{:tag_comment, _, body}, _}, _env) do
    <<"<!", :unicode.characters_to_binary(body)::binary, ?>>>
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
      attrs
      |> Enum.reduce({nil, [], [], []}, fn attr_token,
                                           {attr_ast, base_attrs, merge_attrs, static_attr_tokens} ->
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

    case {attrs_ast, merge_attrs} do
      {nil, []} ->
        Enum.map(static_attr_tokens, &compile_attr(&1, env))

      {nil, _} ->
        [
          quote do
            <<?\s,
              Html.attrs_to_string(Html.merge_attrs(unquote(base_attrs), unquote(merge_attrs)))::binary>>
          end
          | Enum.map(static_attr_tokens, &compile_attr(&1, env))
        ]

      _ ->
        quote do
          [
            case {unquote(attrs_ast), unquote(base_attrs)} do
              {attrs, base_attrs} when attrs not in [nil, []] or base_attrs != [] ->
                <<?\s,
                  Html.attrs_to_string(
                    Html.merge_attrs(
                      Html.merge_attrs(base_attrs, unquote(merge_attrs)) ++
                        unquote(Enum.map(static_attr_tokens, &attr_token_to_tuple(&1, env))),
                      attrs
                    )
                  )::binary>>

              _ ->
                <<unquote_splicing(Enum.map(static_attr_tokens, &compile_attr(&1, env)))>>
            end :: binary
          ]
        end
    end
  end

  @spec compile_attrs(Ast.tag_attr(), env()) :: Macro.t()
  defp compile_attr({:tag_attr, cur, name, value, true}, env) do
    name_string = :erlang.iolist_to_binary(name)

    value_ast =
      quote do
        Html.escape(
          Html.attr_value_to_string(unquote(compile_expr(value, cur, env)), unquote(name_string))
        )
      end

    quote do
      <<?\s, unquote(name_string), ?=, ?", unquote(value_ast)::binary, ?">>
    end
  end

  defp compile_attr({:tag_attr, _cur, name, [], false}, _) do
    <<?\s, :erlang.iolist_to_binary(name)::binary>>
  end

  defp compile_attr({:tag_attr, _cur, name, value, false}, _) do
    <<
      ?\s,
      :erlang.iolist_to_binary(name)::binary,
      ?=,
      ?",
      :unicode.characters_to_binary(value)::binary,
      ?"
    >>
  end

  @spec compile_assigns([Ast.tag_attr()], env()) :: Macro.t()
  defp compile_assigns(attrs, env) do
    {assigns, attrs, assigns_list, attrs_list, merge_attrs} =
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

    case {assigns, assigns_list, attrs_ast} do
      {nil, _, nil} -> {:%{}, [], assigns_list}
      {nil, _, _} -> {:%{}, [], [{:attrs, attrs_ast} | assigns_list]}
      {_, _, nil} -> assigns
      {_, _, _} -> quote(do: Map.put(unquote(assigns), :attrs, unquote(attrs_ast)))
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
        if(unquote(compile_expr(expr, cur, env)), do: unquote(ast), else: unquote(else_ast))
      end

    {ast, tail}
  end

  @spec find_cond_else_expr(Ast.tag_condition(), Macro.t(), [Ast.leaf()], env()) ::
          {Macro.t(), [Ast.leaf()]}
  def find_cond_else_expr(condition, ast, tail, env) do
    case tail do
      [next = {{:tag_start, _, _, _, {:else, _cur, _}, _, _, _, _}, _} | rest] ->
        {compile(next, env), rest}

      [next = {{:tag_start, _, _, _, {:elseif, cur, expr}, _, _, _, _}, _} | rest] ->
        compile_cond_expr({:if, cur, expr}, compile(next, env), rest, env)

      [{{:text_group, _, _}, [{{:tag_text, _, _, _, true}, _}]} | rest] ->
        find_cond_else_expr(condition, ast, rest, env)

      _ ->
        {"", tail}
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
      for(unquote_splicing(compile_expr(expr, cur, env)), do: unquote(ast), into: <<>>)
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
  defp compile_component(component, attrs, children, cur, env) do
    component_ast = compile_expr(component, cur, env)

    assigns_ast = compile_assigns(attrs, env)

    render_args_ast =
      case children do
        [] -> [assigns_ast]
        _ -> [assigns_ast, [do: call(children, env)]]
      end

    quote(do: unquote(component_ast).render(unquote_splicing(render_args_ast)))
  end

  @spec compile_text_group(Ast.leaf(), env()) :: [Macro.t()]
  defp compile_text_group({{:text_group, _, _}, list}, env) do
    list
    |> Enum.reduce([], fn
      {{:tag_text, _, _, _, true}, _}, acc = [" " | _] ->
        acc

      {{:tag_text, _, _, _, true}, _}, acc ->
        [" " | acc]

      head = {{:tag_text, _, [char | _], true, _}, _}, acc ->
        result = String.trim_leading(compile(head, env))

        cond do
          char == ?\n -> [result, "\n" | acc]
          List.first(acc) == " " -> [result | acc]
          true -> [result, " " | acc]
        end

      head, acc ->
        [compile(head, env) | acc]
    end)
    |> reverse_map_binary_ast()
  end

  @spec reverse_map_binary_ast([String.t()]) :: [Macro.t()]
  defp reverse_map_binary_ast(list) do
    Enum.reduce(list, [], fn node, acc ->
      [quote(do: unquote(node) :: binary) | acc]
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
end
