defmodule X.Component do
  defmacro __using__(args) do
    {template_ast, template} = fetch_template(args)
    assigns_ast = fetch_attributes(args)

    quote do
      import X.Template
      import unquote(__MODULE__)

      def template do
        unquote(template)
      end

      def render(args \\ []) do
        unquote(assigns_ast)
        unquote(template_ast)
      end
    end
  end

  defp fetch_template(args) do
    case Keyword.get(args, :template, "") do
      ast = {:sigil_X, _, [template | _]} ->
        {ast, template}

      template when is_bitstring(template) ->
        {quote(do: X.Template.sigil_X(unquote(template), [])), template}
    end
  end

  defp fetch_attributes(args) do
    attrs = Keyword.get(args, :attrs, [])

    X.Component.Attributes.compile(attrs)
  end
end
