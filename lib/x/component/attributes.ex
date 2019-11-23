defmodule X.Component.Attributes do
  def compile(attrs) do
    Enum.map(attrs, fn attr ->
      quote context: X.Component do
        unquote(Macro.var(attr, nil)) = Access.get(args, unquote(attr), "")
      end
    end) ++
      [
        quote context: X.Component do
          unquote(Macro.var(:yield, nil)) = Access.get(args, :do, "")
          _ = var!(yield)
        end
      ]
  end
end
