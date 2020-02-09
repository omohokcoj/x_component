defmodule Mix.Tasks.X.Gen do
  @shortdoc "Generates component file"

  @moduledoc ~S"""
  New component files can be generated with:

      mix x.gen Users.Show

  Generator settings can be adjusted via `:x_component` application configs:

      config :x_component,
        root_path: "lib/app_web/components",
        root_module: "AppWeb.Components",
        generator_template: "\""
          use X.Template
        "\""
  """

  use Mix.Task

  @impl true
  def run(args) do
    cond do
      is_nil(X.root_path()) ->
        Mix.shell().error("""
        Please specify root components path in you config.exs:

          config :x_component,
            root_path: "path/to/components"

        """)

      is_nil(X.root_module()) ->
        Mix.shell().error("""
        Please specify root component module in you config.exs:

          config :x_component,
            root_module: Module.Name

        """)

      true ->
        {_opts, args} = OptionParser.parse!(args, strict: [])

        Enum.each(args, &maybe_generate_file(&1))

        :ok
    end
  end

  defp maybe_generate_file(module_name) do
    file_path = file_path(module_name)

    if File.exists?(file_path) do
      Mix.shell().error("#{file_path} already exists")
    else
      write_file(module_name, file_path)
    end
  end

  defp write_file(module_name, file_path) do
    root_module_name =
      X.root_module()
      |> to_string()
      |> String.trim_leading("Elixir.")

    module = root_module_name <> "." <> module_name
    generator_template = if(X.generator_template(), do: "\n" <> X.generator_template())

    template = """
    defmodule #{module} do#{generator_template}
      use X.Component,
        assigns: %{
        },
        template: ~X"\""
        "\""
    end
    """

    File.mkdir_p!(Path.dirname(file_path))
    File.write!(file_path, template)

    Mix.shell().info("Generated #{module}")
  end

  defp file_path(module_name) do
    X.root_path() <> "/" <> Macro.underscore(module_name) <> ".ex"
  end
end
