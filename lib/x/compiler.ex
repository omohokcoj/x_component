defmodule X.Compiler do
  alias X.Html

  @special_tag_name 'X'
  @assigns_key_name 'assigns'
  @attrs_key_name 'attrs'

  def call(tree, env) do
    call(tree, env, [])
  end

  def call([head = {tag, _} | tail], env, acc) do
    result = compile(head, env)

    result =
      case tag do
        {:tag_start, _, _, _, _, iterator = {:for, _, _}, _, _, _} ->
          compile_for_expr(iterator, result, env)

        _ ->
          result
      end

    {result, tail} =
      case tag do
        {:tag_start, _, _, _, token = {condition, _, _}, _, _, _, _}
        when condition in [:if, :unless] ->
          compile_cond_expr(token, result, tail, env)

        _ ->
          {result, tail}
      end

    call(tail, env, [result | acc])
  end

  def call([], _env, acc) do
    quote do
      <<unquote_splicing(reverse_map_binary_ast(acc))>>
    end
  end

  defp compile(node = {{:text_group, _, _}, _}, env) do
    quote do
      <<unquote_splicing(compile_text_group(node, env))>>
    end
  end

  defp compile({{:tag_output, cur, body, true}, _}, env) do
    quote do
      X.Html.escape(Kernel.to_string(unquote(compile_expr(body, cur, env))))
    end
  end

  defp compile({{:tag_output, cur, body, false}, _}, env) do
    quote do
      Kernel.to_string(unquote(compile_expr(body, cur, env)))
    end
  end

  defp compile({{:tag_text, _, body, _, is_blank}, _}, _env) do
    case is_blank do
      false -> :unicode.characters_to_binary(body)
      _ -> " "
    end
  end

  defp compile({{:tag_start, _, tag_name, attrs, _, _, false, _, false}, children}, env) do
    tag_name_binary = :erlang.iolist_to_binary(tag_name)

    quote do
      <<
        ?<,
        unquote(tag_name_binary)::binary,
        unquote_splicing(compile_attrs(attrs, env)),
        ?>,
        unquote(call(children, env)),
        "</",
        unquote(tag_name_binary)::binary,
        ?>
      >>
    end
  end

  defp compile({{:tag_start, _, tag_name, attrs, _, _, true, _, false}, _}, env) do
    quote do
      <<
        ?<,
        unquote(:erlang.iolist_to_binary(tag_name))::binary,
        unquote_splicing(compile_attrs(attrs, env)),
        ?>
      >>
    end
  end

  defp compile({{:tag_start, cur, @special_tag_name, attrs, _, _, _, _, true}, children}, env) do
    {component, is_tag, attrs} =
      Enum.reduce(attrs, {nil, nil, []}, fn
        {:tag_attr, _, 'component', value, true}, {_, is_tag, acc} -> {value, is_tag, acc}
        {:tag_attr, _, 'is', value, true}, {component, _, acc} -> {component, value, acc}
        attr, {component, is_tag, acc} -> {component, is_tag, [attr | acc]}
      end)

    children_ast = call(children, env)

    cond do
      component ->
        compile_component(component, attrs, children, cur, env)

      is_tag ->
        tag_ast = compile_expr(is_tag, cur, env)
        attrs_ast = compile_attrs(Enum.reverse(attrs), env)

        quote do
          <<
            ?<,
            :erlang.iolist_to_binary(unquote(tag_ast))::binary,
            unquote_splicing(attrs_ast),
            ?>,
            unquote(children_ast),
            "</",
            :erlang.iolist_to_binary(unquote(tag_ast))::binary,
            ?>
          >>
        end

      true ->
        children_ast
    end
  end

  defp compile({{:tag_start, cur, tag_name, attrs, _, _, _, _, true}, children}, env) do
    compile_component(tag_name, attrs, children, cur, env)
  end

  defp compile({{:tag_comment, _, body}, _}, _env) do
    "<!#{body}>"
  end

  defp compile_attrs(attrs, env) do
    Enum.map(attrs, &compile_attr(&1, env))
  end

  defp compile_attr({:tag_attr, cur, @attrs_key_name, value, true}, env) do
    attrs_ast = quote(do: Html.attrs_to_string(unquote(compile_expr(value, cur, env))))

    quote do
      <<?\s, unquote(attrs_ast)::binary>>
    end
  end

  defp compile_attr({:tag_attr, cur, name, value, true}, env) do
    value_ast =
      quote(do: Html.escape(Html.attr_to_string(unquote(compile_expr(value, cur, env)))))

    quote do
      <<?\s, unquote(:erlang.iolist_to_binary(name))::binary, ?=, ?", unquote(value_ast)::binary,
        ?">>
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

  defp compile_assigns(attrs, env) do
    {assigns, attrs, assigns_list, attrs_list} =
      Enum.reduce(attrs, {nil, nil, [], []}, fn {_, cur, name, value, is_dynamic},
                                                {assigns, attrs, assigns_acc, attrs_acc} ->
        if is_dynamic do
          value = compile_expr(value, cur, env)

          case name do
            @assigns_key_name -> {value, attrs, assigns_acc, attrs_acc}
            @attrs_key_name -> {assigns, value, assigns_acc, attrs_acc}
            _ -> {assigns, attrs, [{key_to_atom(name), value} | assigns_acc], attrs_acc}
          end
        else
          {assigns, attrs, assigns_acc,
           [{:erlang.iolist_to_binary(name), :unicode.characters_to_binary(value)} | attrs_acc]}
        end
      end)

    attrs_ast =
      case {attrs, attrs_list} do
        {nil, []} -> nil
        {nil, _} -> attrs_list
        {_, []} -> attrs
        {_, _} -> quote(do: unquote(attrs) ++ unquote(attrs_list))
      end

    case {assigns, assigns_list, attrs_ast} do
      {nil, _, nil} -> {:%{}, [], assigns_list}
      {nil, _, _} -> {:%{}, [], [{:attrs, attrs_ast} | assigns_list]}
      {_, _, nil} -> assigns
      {_, _, _} -> quote(do: Map.put(unquote(assigns), :attrs, unquote(attrs_ast)))
    end
  end

  defp compile_cond_expr({:unless, cur, expr}, ast, tail, env) do
    compile_cond_expr({:if, cur, '!(' ++ expr ++ ')'}, ast, tail, env)
  end

  defp compile_cond_expr(condition = {:if, cur, expr}, ast, tail, env) do
    {else_ast, tail} =
      case tail do
        [next = {{:tag_start, _, _, _, {:else, _cur, _}, _, _, _, _}, _} | rest] ->
          {compile(next, env), rest}

        [next = {{:tag_start, _, _, _, {:elseif, cur, expr}, _, _, _, _}, _} | rest] ->
          compile_cond_expr({:if, cur, expr}, compile(next, env), rest, env)

        [{{:text_group, _, _}, [{{:tag_text, _, _, _, true}, _}]} | rest] ->
          compile_cond_expr(condition, ast, rest, env)

        _ ->
          {"", tail}
      end

    ast =
      quote do
        if(unquote(compile_expr(expr, cur, env)), do: unquote(ast), else: unquote(else_ast))
      end

    {ast, tail}
  end

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

  defp compile_expr(charlist, {_, row}, env) do
    quoted = Code.string_to_quoted!(charlist, line: row + env[:line])

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

  defp compile_text_group({{:text_group, _, _}, list}, env) do
    list
    |> Enum.reduce([], fn
      {{:tag_text, _, _, _, true}, _}, acc = [" " | _] ->
        acc

      {{:tag_text, _, _, _, true}, _}, acc ->
        [" " | acc]

      head = {{:tag_text, _, _, true, _}, _}, acc ->
        result = String.trim_leading(compile(head, env))

        case acc do
          [" " | _] -> [result | acc]
          _ -> [result, " " | acc]
        end

      head, acc ->
        [compile(head, env) | acc]
    end)
    |> reverse_map_binary_ast()
  end

  defp reverse_map_binary_ast(list) do
    Enum.reduce(list, [], fn node, acc ->
      [quote(do: unquote(node) :: binary) | acc]
    end)
  end

  defp key_to_atom(name) do
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
