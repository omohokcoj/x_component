defmodule X do
  @format_sigil_regexp ~r/(\n[^\n]*?~X\""")\n+(.*?)\"""/s

  @doc ~S"""
  Compiles given template string to elixir AST.

  Options:
    * `:line` - the line to be used as the template start.
    * `:context` - compile all variables in given context.
      Variables are not context aware when `nil`.
    * `:inline` - inserts nested components AST into parent component when `true`.
      When `false` nested components will be rendered with `render/2` function.
      Templates compiled with `inline` have better performance.

  ## Examples
      iex> X.compile_string!("<span>Hello {{= example + 1 }} </span>")
      [
        "<span>Hello ",
        {:+, [line: 1], [{:example, [line: 1], nil}, 1]},
        " </span>"
      ]

      iex> X.compile_string!("<span>Hello {{= example + 1 }} </span>", __ENV__, context: Example, line: 10)
      [
        "<span>Hello ",
        {:+, [line: 11], [{:example, [line: 11], Example}, 1]},
        " </span>"
      ]
  """
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

  @doc """
  Formats given component file string.

  ## Examples
      iex> X.format_file!("\""
      ...> defmodule Example do
      ...>   use X.Component,
      ...>     template: ~X"\\""
      ...>       <div> example<span/> <hr> </div>
      ...>     "\\""
      ...> end
      ...> "\"")
      "\""
      defmodule Example do
        use X.Component,
          template: ~X"\\""
          <div> example
            <span />
            <hr>
          </div>
          "\\""
      end
      "\""
  """
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

  @doc ~S"""
  Formats given template string. Returns iodata.

  ## Examples
      iex> X.format_string!("<span><span/>Hello {{= example + 1 }} </span>")
      ["\n", "<", "span", ">", "\n  ", "<", "span", " />", "Hello ",
        "{{", "= ", "example", " +", " ", "1", " }}", " ", "\n", "</", "span", ">"]

  """
  @spec format_string!(String.t(), X.Formatter.options()) :: iodata()
  def format_string!(source, options \\ []) when is_binary(source) and is_list(options) do
    source
    |> X.Tokenizer.call()
    |> X.Parser.call()
    |> X.Formatter.call(options)
  end

  @doc """
  Json library that is used to serialize `map`.
  By default it uses `Phoenix.json_library/1` when used with Phoenix.
  Json library can be set via application config:

      config :x_component,
        json_library: Jason,

  ## Examples

      iex> X.json_library()
      Jason
  """
  @spec json_library() :: atom()
  if Code.ensure_compiled?(Phoenix) do
    def json_library, do: Application.get_env(:x_component, :json_library, Phoenix.json_library())
  else
    def json_library, do: Application.get_env(:x_component, :json_library)
  end

  @doc """
  By default all components are compiled with `inline` option for faster rendering.
  `inline` option is disabled when extracting gettext to provide context aware AST.
  To get faster code reload in developemnt `inline` option can be disabled via config:

      config :x_component,
        compile_inline: false,

  ## Examples

      iex> X.compile_inline?()
      true
  """
  @spec compile_inline?() :: boolean()
  if Code.ensure_compiled?(Gettext.Extractor) do
    def compile_inline? do
      !Gettext.Extractor.extracting?() && Application.get_env(:x_component, :compile_inline, true)
    end
  else
    def compile_inline?, do: Application.get_env(:x_component, :compile_inline, true)
  end

  @doc """
  Root component module that is used by components generator and Phoenix.

      config :x_component,
        root_module: "MyApp.Components"

  ## Examples

      iex> X.root_module()
      "X.Components"
  """
  @spec root_module() :: atom() | binary() | nil
  def root_module do
    Application.get_env(:x_component, :root_module)
  end

  @doc """
  Components directory path used by generator task.

      config :x_component,
        root_path: "lib/my_app_web/components",

  ## Examples

      iex> X.root_path()
      "tmp"
  """
  @spec root_path() :: String.t() | nil
  def root_path do
    Application.get_env(:x_component, :root_path)
  end

  @doc ~S"""
  Elixir code snippet that will be added to the body of the component module created via generator task.

      config :x_component,
        generator_template: "\""
          use MyAppWeb, :component
          import String
        "\""

  ## Examples

      iex> X.generator_template()
      "  use X.Template\n"
  """
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
