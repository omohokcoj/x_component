defmodule X.Transformer do
  @spec compact_ast(Macro.t()) :: Macro.t()
  def compact_ast(tree) when is_list(tree) do
    tree
    |> List.flatten()
    |> join_binary()
  end

  def compact_ast(tree) do
    tree
  end

  @spec transform_expresion(Macro.t(), atom(), Macro.Env.t()) :: Macro.t()
  def transform_expresion(ast, context, env) do
    Macro.postwalk(ast, fn
      {:@, meta, [{name, _, atom}]} when is_atom(name) and is_atom(atom) ->
        line = Keyword.get(meta, :line, 0)

        case name do
          :assigns ->
            quote(line: line, do: unquote(Macro.var(:assigns, nil)))

          :yield ->
            quote(line: line, do: unquote(Macro.var(:yield, context)))

          _ ->
            quote line: line do
              Map.get(unquote(Macro.var(:assigns, nil)), unquote(name))
            end
        end

      ast = {:__aliases__, _, _} ->
        Macro.expand(ast, env)

      {variable, meta, nil} when is_atom(variable) ->
        {variable, meta, context}

      ast = {function, _, args} when not is_nil(context) and is_atom(function) and is_list(args) ->
        alias_function(ast, env)

      a ->
        a
    end)
  end

  @spec transform_inline_component(atom(), Keyword.t(), Macro.t(), integer()) :: Macro.t()
  def transform_inline_component(module, assigns, children, line) do
    module.template_ast()
    |> Macro.prewalk(fn
      ast =
          {:case, _,
           [
             {{{:., _, [{:__aliases__, _, [:Map]}, :get]}, _, [{:assigns, _, _}, :attrs]},
              base_attrs},
             block_ast
           ]} ->
        case Keyword.get(assigns, :attrs) do
          nil ->
            transform_inline_attributes([], base_attrs, block_ast, line)

          attrs when is_list(attrs) ->
            transform_inline_attributes(attrs, base_attrs, block_ast, line)

          _ ->
            ast
        end

      ast = {{:., _, [{:__aliases__, _, [:Map]}, :get]}, _, [{:assigns, _, _}, variable]} ->
        Keyword.get(assigns, variable, ast)

      ast ->
        ast
    end)
    |> Macro.postwalk(fn
      {:yield, _, _} ->
        children

      {:assigns, _, context} when not is_nil(context) ->
        {:%{}, [line: line], assigns}

      {variable, _, ^module} when is_atom(variable) ->
        case Keyword.get(module.assigns(), variable) do
          nil ->
            {variable, [line: line], module}

          true ->
            Keyword.get_lazy(assigns, variable, fn ->
              throw({:missing_assign, {1, line}, variable})
            end)

          false ->
            Keyword.get(assigns, variable)
        end

      {term, _meta, args} ->
        {term, [line: line], args}

      ast ->
        ast
    end)
  end

  @spec transform_inline_attributes(Keyword.t(), Keyword.t(), Macro.t(), integer()) :: Macro.t()
  defp transform_inline_attributes(attrs, base_attrs, block_ast, line) do
    dynamic_values =
      Enum.reduce(attrs ++ base_attrs, [], fn {key, value}, acc ->
        case value do
          {_, _, _} ->
            [key | acc]

          value when is_list(value) ->
            is_dynamic = Enum.any?(value, &is_tuple(&1))

            if(is_dynamic, do: [key | acc], else: acc)

          _ ->
            acc
        end
      end)

    {attrs_dynamic, attrs_static} =
      Enum.split_with(attrs, fn {key, _} -> key in dynamic_values end)

    {base_dynamic, base_static} =
      Enum.split_with(base_attrs, fn {key, _} -> key in dynamic_values end)

    dynamic_ast =
      case {attrs_dynamic, base_dynamic} do
        {[], []} ->
          []

        {[], _} ->
          [?\s, quote(line: line, do: X.Html.attrs_to_iodata(unquote(base_dynamic)))]

        {_, []} ->
          [?\s, quote(line: line, do: X.Html.attrs_to_iodata(unquote(attrs_dynamic)))]

        {_, _} ->
          [
            ?\s,
            quote line: line do
              X.Html.attrs_to_iodata(
                X.Html.merge_attrs(unquote(attrs_dynamic), unquote(base_dynamic))
              )
            end
          ]
      end

    [_, {:->, _, [[{:_, _, _}], attrs_iodata]}] = Keyword.get(block_ast, :do)

    [
      ?\s,
      X.Html.attrs_to_iodata(X.Html.merge_attrs(attrs_static, base_static)),
      dynamic_ast,
      attrs_iodata
    ]
  end

  @spec alias_function(Macro.expr(), Macro.Env.t()) :: Macro.t()
  defp alias_function(ast = {function, meta, args}, env) do
    context = env.functions ++ env.macros
    args_length = length(args)

    if Macro.special_form?(function, args_length) || Macro.operator?(function, args_length) do
      ast
    else
      imported_module =
        Enum.find(context, fn {_, fns} ->
          Enum.any?(fns, fn {name, arity} ->
            name == function && args_length == arity
          end)
        end)

      alias_module =
        case imported_module do
          {module, _} -> module
          nil -> env.module
        end

      {{:., meta, [{:__aliases__, [], [alias_module]}, function]}, meta, args}
    end
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
    :lists.reverse([IO.iodata_to_binary(iodata) | acc])
  end
end
