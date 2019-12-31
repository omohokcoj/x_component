defmodule X do
  defmodule SyntaxError do
    defexception [:message, :file, :line]

    def message(exception) do
      "#{exception.file}:#{exception.line}: #{exception.message}"
    end
  end

  @format_sigil_regexp ~r/(\n[^\n]*?~X\""")\n+(.*?)\"""/s

  def compile_string!(source, options \\ []) when is_binary(source) and is_list(options) do
    source
    |> X.Tokenizer.call()
    |> X.Parser.call()
    |> X.Compiler.call(options)
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
end
