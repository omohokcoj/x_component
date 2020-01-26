defmodule X do
  @format_sigil_regexp ~r/(\n[^\n]*?~X\""")\n+(.*?)\"""/s

  @spec compile_string!(String.t()) :: Macro.t()
  @spec compile_string!(String.t(), Macro.Env.t()) :: Macro.t()
  @spec compile_string!(String.t(), Macro.Env.t(), X.Compiler.options()) :: Macro.t()
  def compile_string!(source, env \\ __ENV__, options \\ [])
      when is_binary(source) and is_map(env) do
    source
    |> X.Tokenizer.call()
    |> X.Parser.call()
    |> X.Compiler.call(env, options)
  catch
    exception -> process_exception(exception, env, options)
  end

  @spec format_file!(String.t()) :: String.t()
  def format_file!(file) when is_binary(file) do
    Regex.replace(@format_sigil_regexp, file, fn _, head, template ->
      identation = List.first(Regex.split(~r/[^\n\s]/, head))

      spaces_count =
        identation
        |> String.to_charlist()
        |> Enum.count(&(&1 == ?\s))

      IO.iodata_to_binary([head, format_string!(template, nest: spaces_count), identation, '"""'])
    end)
  end

  @spec format_string!(String.t(), X.Formatter.options()) :: iodata()
  def format_string!(source, options \\ []) when is_binary(source) and is_list(options) do
    source
    |> X.Tokenizer.call()
    |> X.Parser.call()
    |> X.Formatter.call(options)
  end

  @spec json_library() :: atom()
  if Code.ensure_compiled?(Phoenix) do
    def json_library, do: Phoenix.json_library()
  else
    def json_library, do: Application.get_env(:x_component, :json_library)
  end

  @spec compile_inline?() :: boolean()
  if Code.ensure_compiled?(Gettext.Extractor) do
    def compile_inline? do
      !Gettext.Extractor.extracting?() && Application.get_env(:x_component, :compile_inline, true)
    end
  else
    def compile_inline?, do: Application.get_env(:x_component, :compile_inline, true)
  end

  @spec root_module() :: atom() | nil
  def root_module do
    Application.get_env(:x_component, :root_module)
  end

  @spec root_path() :: String.t() | nil
  def root_path do
    Application.get_env(:x_component, :root_path)
  end

  @spec generator_template() :: String.t() | nil
  def generator_template do
    Application.get_env(:x_component, :generator_template)
  end

  defp process_exception({:unexpected_tag, {_, row}, nil, actual_tag}, env, opts) do
    raise SyntaxError,
      description: "Unexpected tag close '#{actual_tag}'",
      line: row + Keyword.get(opts, :line, env.line),
      file: env.file
  end

  defp process_exception({:unexpected_tag, {_, row}, expected_tag, actual_tag}, env, opts) do
    raise SyntaxError,
      description: "Unexpected tag: expected tag '#{expected_tag}' but got '#{actual_tag}'",
      line: row + Keyword.get(opts, :line, env.line),
      file: env.file
  end

  defp process_exception({:unexpected_token, {_, row}, char}, env, opts) do
    raise SyntaxError,
      description: "Unexpected token at '#{<<char>>}'",
      line: row + Keyword.get(opts, :line, env.line),
      file: env.file
  end

  defp process_exception({:missing_assign, {_, row}, assign_name}, env, _) do
    raise CompileError,
      description: "Missing required assign :#{assign_name}",
      line: row,
      file: env.file
  end
end
