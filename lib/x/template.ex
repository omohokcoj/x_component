defmodule X.Template do
  defmacro __using__(_) do
    quote do
      import unquote(__MODULE__)
    end
  end

  defmacro sigil_X(expr, 's') do
    quote do
      IO.iodata_to_binary(unquote(handle_sigil(expr, __CALLER__)))
    end
  end

  defmacro sigil_X(expr, _) do
    handle_sigil(expr, __CALLER__)
  end

  @spec handle_sigil(Macro.t(), Macro.Env.t()) :: Macro.t()
  defp handle_sigil({:<<>>, _, [expr]}, env) do
    X.compile_string!(expr, env, line: env.line)
  end

  defp handle_sigil(expr, env) when is_bitstring(expr) do
    X.compile_string!(expr, env, line: env.line)
  end
end
