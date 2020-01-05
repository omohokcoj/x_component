defmodule X.Component do
  @type options() :: [
          {:assigns, map() | [atom()]}
          | {:template, Macro.t()}
        ]

  @reserved_dynamic_attrs [
    :class,
    :style,
    :assigns,
    :attrs
  ]

  defmacro __using__(options) when is_list(options) do
    {template_ast, template} = fetch_template(options)
    assigns_ast = fetch_assigns(options, __CALLER__)
    component_doc = build_component_doc(template, assigns_ast)

    quote do
      use X.Template

      @moduledoc if @moduledoc,
                   do: Enum.join([@moduledoc, unquote(component_doc)], "\n"),
                   else: unquote(component_doc)

      @spec template() :: String.t()
      def template do
        unquote(template)
      end

      X.Component.define_render_functions(unquote(template_ast), unquote(assigns_ast))
    end
  end

  defmacro define_render_functions(template_ast, assigns_ast) do
    assigns_typespec = build_assigns_typespec(assigns_ast)
    assigns_vars_ast = build_assigns_vars_ast(assigns_ast, __CALLER__)

    quote do
      @spec render_to_string(unquote(assigns_typespec)) :: String.t()
      @spec render_to_string(unquote(assigns_typespec), [{:do, iodata() | nil}]) :: String.t()
      def render_to_string(assigns, options \\ [do: nil]) do
        IO.iodata_to_binary(render(assigns, options))
      end

      @spec render(unquote(assigns_typespec)) :: iodata()
      def render(assigns) do
        render(assigns, do: nil)
      end

      @spec render(unquote(assigns_typespec), [{:do, iodata() | nil}]) :: iodata()
      def render(var!(assigns), [{:do, var!(yield)}]) do
        _ = var!(yield)
        _ = var!(assigns)
        unquote(assigns_vars_ast)
        unquote(template_ast)
      end
    end
  end

  @spec fetch_template(options()) :: {Macro.t(), String.t()}
  defp fetch_template(options) do
    case Keyword.get(options, :template, "") do
      ast = {:sigil_X, _, [{:<<>>, _, [template]} | _]} ->
        {ast, template}

      template when is_bitstring(template) ->
        {quote(do: X.Template.sigil_X(unquote(template), [])), template}
    end
  end

  @spec fetch_assigns(options(), Macro.Env.t()) :: Macro.t()
  defp fetch_assigns(options, env) do
    assigns = Keyword.get(options, :assigns, [])

    if is_list(assigns) do
      {:%{}, [], Enum.map(assigns, &{&1, quote(do: any())})}
    else
      Macro.postwalk(assigns, fn
        ast = {:__aliases__, _, _} ->
          Macro.expand_once(ast, env)

        {:required, [_], [atom]} ->
          atom

        ast ->
          ast
      end)
    end
  end

  @spec build_component_doc(String.t(), Macro.t()) :: String.t()
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

  @spec build_assigns_typespec(Macro.t()) :: Macro.t()
  defp build_assigns_typespec({:%{}, context, assigns}) do
    optional_keys = [
      quote(do: {optional(:attrs), [{binary(), any()}]}),
      quote(do: {atom(), any()})
    ]

    {:%{}, context, assigns ++ optional_keys}
  end

  @spec build_assigns_vars_ast(Macro.t() | [atom()], any()) :: Macro.t()
  defp build_assigns_vars_ast({:%{}, [_], assigns}, env) do
    Enum.map(assigns, fn
      {{:optional, [line: line], [attr]}, _} ->
        maybe_warn_reserved_attribute(attr, %{env | line: line})

        quote do
          unquote(Macro.var(attr, nil)) = Map.get(var!(assigns), unquote(attr))
        end

      {attr, _} ->
        maybe_warn_reserved_attribute(attr, env)

        quote do
          unquote(Macro.var(attr, nil)) = var!(assigns).unquote(attr)
        end
    end)
  end

  defp maybe_warn_reserved_attribute(attr, env) do
    if attr in @reserved_dynamic_attrs do
      IO.warn(
        ~s(property "#{to_string(attr)}" is reserved for dynamic tag attributes),
        Macro.Env.stacktrace(env)
      )
    end
  end
end
