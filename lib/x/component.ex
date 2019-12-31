defmodule X.Component do
  defmacro __using__(args) do
    {template_ast, template} = fetch_template(args)
    assigns = fetch_assigns(args, __CALLER__)
    component_doc = build_component_doc(template, assigns)

    quote do
      use X.Template

      @moduledoc X.Component.merge_docs(@moduledoc, unquote(component_doc))

      def template do
        unquote(template)
      end

      X.Component.define_render_function(unquote(template_ast), unquote(assigns))
    end
  end

  defmacro define_render_function(template, assigns) do
    assigns_typespec = build_assigns_typespec(assigns)
    assigns_ast = build_assigns_ast(assigns)

    quote do
      @spec render(unquote(assigns_typespec)) :: binary()
      def render(var!(assigns)) do
        var!(yield) = nil
        _ = var!(yield)
        _ = var!(assigns)
        unquote(assigns_ast)
        unquote(template)
      end

      @spec render(unquote(assigns_typespec), [{:do, binary()}]) :: binary()
      def render(var!(assigns), [{:do, var!(yield)}]) do
        _ = var!(yield)
        _ = var!(assigns)
        unquote(assigns_ast)
        unquote(template)
      end
    end
  end

  defp fetch_template(args) do
    case Keyword.get(args, :template, "") do
      ast = {:sigil_X, _, [{:<<>>, _, [template]} | _]} ->
        {ast, template}

      template when is_bitstring(template) ->
        {quote(do: X.Template.sigil_X(unquote(template), [])), template}
    end
  end

  defp fetch_assigns(args, env) do
    assigns = Keyword.get(args, :assigns, Macro.escape(%{}))

    Macro.postwalk(assigns, fn
      ast = {:__aliases__, _, _} ->
        Macro.expand_once(ast, env)

      {:required, [_], [atom]} ->
        atom

      ast ->
        ast
    end)
  end

  defp build_component_doc(template, assigns) do
    Enum.join(
      [
        "## Assigns:",
        Code.format_string!(Macro.to_string(assigns), line_length: 60),
        "## Template:",
        template
      ],
      "\n\n"
    )
  end

  def merge_docs(module_doc, component_doc) do
    case module_doc do
      nil -> component_doc
      _ -> Enum.join([module_doc, component_doc], "\n")
    end
  end

  defp build_assigns_typespec(assigns) do
    any_key_ast = [quote(do: {atom(), any()})]

    case assigns do
      {:%{}, [_], assigns} ->
        {:%{}, [], assigns ++ any_key_ast}

      _ ->
        {:%{}, [], Enum.map(assigns, &{&1, quote(do: any())}) ++ any_key_ast}
    end
  end

  defp build_assigns_ast({:%{}, [_], assigns}) do
    Enum.map(assigns, fn
      {{:optional, _, [attr]}, _} ->
        quote do
          unquote(Macro.var(attr, nil)) = Map.get(var!(assigns), unquote(attr))
        end

      {attr, _} ->
        quote do
          unquote(Macro.var(attr, nil)) = var!(assigns).unquote(attr)
        end
    end)
  end

  defp build_assigns_ast(assigns) when is_list(assigns) do
    Enum.map(assigns, fn attr ->
      quote do
        unquote(Macro.var(attr, nil)) = var!(assigns).unquote(attr)
      end
    end)
  end
end
