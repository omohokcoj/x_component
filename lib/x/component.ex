defmodule X.Component do
  @moduledoc ~S"""
  Extends given module with the X component functions:

  ## Example

      defmodule ExampleComponent do
        use X.Component,
          assigns: %{
            :message => String.t()
          },
          template: ~X"\""
          <div>
            {{ message }}
            {{= yield }}
          </div>
          "\""
      end

    * `:assigns` - list of component assigned variables. Types can be defined with Elixir typespecs:

          use X.Component,
            assigns: %{
              :book => any(),
              :message => String.t(),
              :items => [{atom(), String.t(), boolean()}],
              optional(:active) => nil | boolean()
            }

    * `:template` - component X template.

  ## Component functions:

    * `render/1`, `render/2` - renders component as `iodata`. Render function can accept nested `iodata` elements:

          ExampleComponent.render(%{message: "Example"}) do
            [
              ~X"\""
              <form action="/test">
                <input name="title">
              </form>
              "\"",
              Button.render(%{test: "Submit"})
            ]
          end

    * `render_to_string/1`, `render_to_string/2` - renders component to `bitstring`.

    * `assigns/0` - returns a list of assigns with tuples where the first element is for the assign `atom` name and the second element is for required (`true`) and optional (`false`) assigns.

          ExampleComponent.assigns()
          # [message: true]

    * `template/0` - returns X template string.

          ExampleComponent.template()
          # "<div>\n  {{ message }}\n  {{= yield }}\n</div>\n"
  """

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
    {template, line} = fetch_template(options)

    compiler_opts = [line: line, inline: X.compile_inline?(), context: __CALLER__.module]
    template_ast = X.compile_string!(template, __CALLER__, compiler_opts)

    assigns_ast = fetch_assigns(options, __CALLER__)
    assigns_list = build_assigns_list(assigns_ast)
    component_doc = build_component_doc(template, assigns_ast)

    quote do
      @moduledoc if @moduledoc,
                   do: Enum.join([@moduledoc, unquote(component_doc)], "\n"),
                   else: unquote(component_doc)

      @spec template() :: String.t()
      def template do
        unquote(template)
      end

      @spec template_ast() :: Macro.t()
      def template_ast do
        unquote(Macro.escape(template_ast))
      end

      @spec assigns() :: [{name :: atom(), required :: boolean()}]
      def assigns do
        unquote(assigns_list)
      end

      X.Component.define_render_functions(unquote(template_ast), unquote(assigns_ast))
    end
  end

  @doc false
  defmacro define_render_functions(template_ast, assigns_ast) do
    assigns_typespec = build_assigns_typespec(assigns_ast)
    {optional_vars_ast, required_vars_ast} = build_assigns_vars_ast(assigns_ast, __CALLER__)

    %{module: module} = __CALLER__

    quote do
      @spec render_to_string(unquote(assigns_typespec)) :: String.t()
      @spec render_to_string(unquote(assigns_typespec), [{:do, iodata() | nil}]) :: String.t()
      def render_to_string(assigns, options \\ [do: nil]) do
        assigns
        |> render(options)
        |> IO.iodata_to_binary()
      end

      @spec render(unquote(assigns_typespec)) :: iodata()
      def render(assigns) do
        render(assigns, do: nil)
      end

      @spec render(unquote(assigns_typespec), [{:do, iodata() | nil}]) :: iodata()
      def render(
            unquote(Macro.var(:assigns, nil)) = unquote({:%{}, [], required_vars_ast}),
            [{:do, unquote(Macro.var(:yield, module))}]
          ) do
        _ = unquote(Macro.var(:assigns, nil))
        _ = unquote(Macro.var(:yield, module))
        unquote_splicing(optional_vars_ast)
        unquote(template_ast)
      end
    end
  end

  @spec fetch_template(options()) :: {Macro.t(), integer() | nil}
  defp fetch_template(options) do
    case Keyword.get(options, :template, "") do
      {:sigil_X, _, [{:<<>>, [line: line], [template]} | _]} ->
        {template, line}

      template when is_bitstring(template) ->
        {template, nil}
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

  @spec build_assigns_list(Macro.t()) :: [{name :: atom(), required :: boolean()}]
  defp build_assigns_list({:%{}, _, assigns}) do
    Enum.map(assigns, fn
      {{spec, _, [attr]}, _} ->
        {attr, spec != :optional}

      {attr, _} ->
        {attr, true}
    end)
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

  @spec build_assigns_vars_ast(Macro.t() | [atom()], any()) :: {Macro.t(), Macro.t()}
  defp build_assigns_vars_ast({:%{}, [_], assigns}, env) do
    %{module: module} = env

    Enum.reduce(assigns, {[], []}, fn
      {{:optional, [line: line], [attr]}, _}, {optional, required} ->
        maybe_warn_reserved_attribute(attr, %{env | line: line})

        {[
           quote do
             unquote(Macro.var(attr, module)) =
               Map.get(unquote(Macro.var(:assigns, nil)), unquote(attr))
           end
           | optional
         ], required}

      {attr, _}, {optional, required} ->
        maybe_warn_reserved_attribute(attr, env)

        {optional, [{attr, Macro.var(attr, module)} | required]}
    end)
  end

  @spec maybe_warn_reserved_attribute(atom(), Macro.Env.t()) :: :ok | nil
  defp maybe_warn_reserved_attribute(attr, env) do
    if attr in @reserved_dynamic_attrs do
      IO.warn(
        ~s(property "#{to_string(attr)}" is reserved for dynamic tag attributes),
        Macro.Env.stacktrace(env)
      )
    end
  end
end
