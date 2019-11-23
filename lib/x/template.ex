defmodule X.Template do
  defmacro __using__(_) do
    quote do
      import unquote(__MODULE__)
    end
  end

  defmacro sigil_X(expr, opts) do
    handle_sigil(expr, opts, __CALLER__.line)
  end

  defp handle_sigil({:<<>>, _, [expr]}, [], line) do
    X.compile_string!(expr, line: line + 1)
  end

  defp handle_sigil(expr, [], line) when is_bitstring(expr) do
    X.compile_string!(expr, line: line + 1)
  end
end
