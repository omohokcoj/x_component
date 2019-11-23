defmodule X.Compiler do
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
        {:tag_start, _, _, _, condition = {:if, _, _}, _, _, _, _} ->
          compile_cond_expr(condition, result, tail, env)

        {:tag_start, _, _, _, {:unless, cur, expr}, _, _, _, _} ->
          compile_cond_expr({:if, cur, "!(#{expr})"}, result, tail, env)

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

  defp compile({{:text_group, _, _}, children}, env) do
    quote do
      <<unquote_splicing(compile_text_group(children, env))>>
    end
  end

  defp compile({{:tag_output, _, body, true}, _}, env) do
    quote do
      X.Html.escape(to_string(unquote(compile_expr(body, env))))
    end
  end

  defp compile({{:tag_output, _, body, false}, _}, env) do
    quote do
      to_string(unquote(compile_expr(body, env)))
    end
  end

  defp compile({{:tag_text, _, body, _, is_blank}, _}, _env) do
    case is_blank do
      false -> List.to_string(body)
      _ -> " "
    end
  end

  defp compile({{:tag_start, _, tag_name, attrs, _, _, false, _, false}, children}, env) do
    quote do
      <<
        unquote("<#{tag_name}"),
        unquote_splicing(compile_attrs(attrs, env)),
        ">",
        unquote(call(children, env)),
        unquote("</#{tag_name}>")
      >>
    end
  end

  defp compile({{:tag_start, _, tag_name, attrs, _, _, true, _, false}, _}, env) do
    quote do
      <<
        unquote("<#{tag_name}"),
        unquote_splicing(compile_attrs(attrs, env)),
        ">"
      >>
    end
  end

  defp compile({{:tag_start, _, tag_name, attrs, _, _, _, _, true}, children}, env) do
    component = compile_expr(tag_name, env)

    args = [{:do, call(children, env)} | compile_args(attrs, env)]

    quote(do: unquote(component).render(unquote(args)))
  end

  defp compile_attrs(attrs, env) do
    attrs
    |> Enum.reduce([], fn {_, _cur, name, value, is_dynamic}, acc ->
      case is_dynamic do
        true ->
          [
            <<?">>,
            quote(do: X.Html.attr_to_string(unquote(compile_expr(value, env)))),
            ~s( #{name}=") | acc
          ]

        _ ->
          case value do
            [] ->
              [" #{name}" | acc]

            _ ->
              [~s( #{name}="#{value}") | acc]
          end
      end
    end)
    |> reverse_map_binary_ast()
  end

  defp compile_args(args, env) do
    Enum.map(args, fn {_, _cur, name, value, is_dynamic} ->
      value =
        if is_dynamic do
          compile_expr(value, env)
        else
          to_string(value)
        end

      {String.to_atom(to_string(name)), value}
    end)
  end

  defp compile_cond_expr(condition = {:if, _cur, expr}, ast, tail, env) do
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
        if(unquote(compile_expr(expr, env)), do: unquote(ast), else: unquote(else_ast))
      end

    {ast, tail}
  end

  defp compile_for_expr({:for, _cur, expr}, ast, env) do
    expr =
      case expr do
        '[' ++ expr -> expr
        _ -> [?[ | expr] ++ ']'
      end

    quote do
      for(unquote_splicing(compile_expr(expr, env)), do: unquote(ast), into: <<>>)
    end
  end

  defp compile_expr(charlist, _env) do
    quoted = Code.string_to_quoted!(charlist)

    Macro.postwalk(quoted, fn
      {:@, meta, [{name, _, atom}]} when is_atom(name) and is_atom(atom) ->
        quote line: Keyword.get(meta, :line, 0) do
          name = unquote(if(name == :yield, do: :do, else: name))

          Access.get(var!(assigns), name)
        end

      a ->
        a
    end)
  end

  defp compile_text_group(list, env) do
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
end
