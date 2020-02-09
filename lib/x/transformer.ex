defmodule X.Transformer do
  @moduledoc """
  Contains a set of functions to transform compiled Elixir AST
  into more performance optimized AST.
  Also, it contains functions to transform Elixir AST for inline components.
  """

  @spec compact_ast(Macro.t()) :: Macro.t()
  def compact_ast(tree) when is_list(tree) do
    tree
    |> List.flatten()
    |> join_binary()
  end

  def compact_ast(tree) do
    tree
  end

  @doc """
  Transform given Elixir AST into a valid X template AST.

    * transforms globals `@var` into assigns `Map.get/2` function call.
    * transforms `@assigns` and `@yield` into local variables.
    * add given `context` module to the local variables context.
    * transforms imported function call into function call from the imported module.
    * expands all aliases.
  """
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

      ast = {function, _, args}
      when not is_nil(context) and is_atom(function) and is_list(args) ->
        alias_function(ast, env)

      a ->
        a
    end)
  end

  @doc """
  Transform given X template Elixir AST into optimized inline component AST.

    * replaces dynamic `:attrs` with string build in compile time when it's possible.
    * replaces local variables with given `assigns`.
    * replaces `yield` local variables with given `children` AST.
  """
  @spec transform_inline_component(atom(), Keyword.t(), Macro.t(), integer()) :: Macro.t()
  def transform_inline_component(module, assigns, children, line) do
    module.template_ast()
    |> Macro.postwalk(fn
      ast = {{:., _, [{:__aliases__, _, [:Map]}, :get]}, _, [{:assigns, _, _}, variable]} ->
        Keyword.get(assigns, variable, ast)

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
    |> Macro.prewalk(fn
      ast = {:case, _, [{:{}, _, [attrs, base_attrs, static_attrs]}, _]} ->
        if is_list(attrs) || is_nil(attrs) do
          transform_inline_attributes(attrs || [], base_attrs, static_attrs, line)
        else
          ast
        end

      ast ->
        ast
    end)
  end

  @spec transform_inline_attributes(list(), list(), list(), integer()) :: Macro.t()
  defp transform_inline_attributes(attrs, base_attrs, static_attrs, line) do
    attrs = X.Html.merge_attrs(X.Html.merge_attrs(base_attrs, static_attrs), attrs)

    {dynamic_attrs, static_attrs} =
      Enum.split_with(attrs, fn
        {{_, _, _}, _} ->
          true

        {_, value} ->
          case value do
            {_, _, _} ->
              true

            value when is_list(value) ->
              Enum.any?(value, fn
                {key, value} -> is_tuple(value) or is_tuple(key)
                value -> is_tuple(value)
              end)

            _ ->
              false
          end
      end)

    case dynamic_attrs do
      [] ->
        [?\s, X.Html.attrs_to_iodata(static_attrs)]

      _ ->
        dynamic_ast =
          quote line: line do
            X.Html.attrs_to_iodata(unquote(dynamic_attrs))
          end

        [?\s, dynamic_ast, ?\s, X.Html.attrs_to_iodata(static_attrs)]
    end
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

  defp join_binary([ast = {_, _, _} | tail], [], acc) do
    join_binary(tail, [], [ast | acc])
  end

  defp join_binary([ast = {_, _, _} | tail], iodata, acc) do
    join_binary(tail, [], [ast, IO.iodata_to_binary(iodata) | acc])
  end

  defp join_binary([head | tail], iodata, acc) do
    join_binary(tail, [iodata, head], acc)
  end

  defp join_binary([], [], []) do
    []
  end

  defp join_binary([], iodata, []) do
    IO.iodata_to_binary(iodata)
  end

  defp join_binary([], [], acc) do
    :lists.reverse(acc)
  end

  defp join_binary([], iodata, acc) do
    :lists.reverse([IO.iodata_to_binary(iodata) | acc])
  end
end
