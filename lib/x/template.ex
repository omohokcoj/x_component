defmodule X.Template do
  @moduledoc """
  Extends module with `~X` sigil to compile templates.

      use X.Template
  """

  defmacro __using__(_) do
    quote do
      import unquote(__MODULE__)
    end
  end

  @doc ~S"""
  Handles sigil `~X` for the X templates.
  It returns Elixir AST which can be injected into the function body:

      iex> defmodule Example do
      ...>   use X.Template
      ...>
      ...>   def render(assigns) do
      ...>     ~X(<div>{{ assigns.message }}</div>)
      ...>   end
      ...> end
      ...> Example.render(%{message: "test"})
      ["<div>", "test", "</div>"]

  By default `~X` sigil returns `iodata` AST. The `s` modifier is used to return string:

      iex> use X.Template
      ...> message = "Test"
      ...> ~X(<div>{{ message }}</div>)s
      "<div>Test</div>"
  """
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
