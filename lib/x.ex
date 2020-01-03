defmodule X do
  @format_sigil_regexp ~r/(\n[^\n]*?~X\""")\n+(.*?)\"""/s

  if Code.ensure_compiled?(Phoenix) do
    def json_library, do: Phoenix.json_library()
  else
    def json_library, do: Application.get_env(:x_component, :json_library)
  end

  def compile_string!(source, env \\ []) when is_binary(source) and is_list(env) do
    source
    |> X.Tokenizer.call()
    |> X.Parser.call()
    |> X.Compiler.call(env)
  catch
    exception -> process_exception(exception, env)
  end

  def format_file!(file) when is_binary(file) do
    Regex.replace(@format_sigil_regexp, file, fn _, head, template ->
      identation = List.first(Regex.split(~r/[^\n\s]/, head))

      spaces_count =
        identation
        |> String.to_charlist()
        |> Enum.count(&(&1 == ?\s))

      head <> format_string!(template, nest: spaces_count) <> identation <> ~s(""")
    end)
    |> String.trim()
  end

  def format_string!(source, options \\ []) when is_binary(source) and is_list(options) do
    source
    |> X.Tokenizer.call()
    |> X.Parser.call()
    |> X.Formatter.call(options)
  end

  defp process_exception({:unexpected_tag, {_, row}, nil, actual_tag}, env) do
    raise SyntaxError,
      description: "Unexpected tag close '#{actual_tag}'",
      line: row + env[:line],
      file: env[:file]
  end

  defp process_exception({:unexpected_tag, {_, row}, expected_tag, actual_tag}, env) do
    raise SyntaxError,
      description: "Unexpected tag: expected tag '#{expected_tag}' but got '#{actual_tag}'",
      line: row + env[:line],
      file: env[:file]
  end

  defp process_exception({:unexpected_token, {_, row}, char}, env) do
    raise SyntaxError,
      description: "Unexpected token at '#{<<char>>}'",
      line: row + env[:line],
      file: env[:file]
  end
end
