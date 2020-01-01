defmodule X.Template do
  defmacro __using__(_) do
    quote do
      import unquote(__MODULE__)
    end
  end

  defmacro sigil_X(expr, opts) do
    handle_sigil(expr, opts, line: __CALLER__.line, file: __CALLER__.file)
  end

  defp handle_sigil({:<<>>, _, [expr]}, [], env) do
    X.compile_string!(expr, env)
  end

  defp handle_sigil(expr, [], env) when is_bitstring(expr) do
    X.compile_string!(expr, env)
  end
end
