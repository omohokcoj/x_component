defmodule X.MixProject do
  use Mix.Project

  @version "0.1.0"
  @project_url "https://github.com/omohokcoj/x_component"

  def project do
    [
      app: :x_component,
      version: @version,
      elixir: "~> 1.9",
      deps: deps(),
      docs: docs(),
      description: description(),
      package: package(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.travis": :test,
        "coveralls.html": :test
      ],
      dialyzer: [
        plt_add_apps: [:mix],
        check_plt: true
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp description do
    """
    Component-based HTML templates for Elixir/Phoenix, inspired by Vue.
    """
  end

  defp package do
    [
      name: :x_component,
      files: ["lib", "mix.exs", "README.md", "config"],
      maintainers: ["Pete Matsyburka"],
      licenses: ["MIT"],
      links: %{"GitHub" => @project_url, "Docs" => "https://hexdocs.pm/x_component"}
    ]
  end

  defp docs do
    [main: "readme", source_url: @project_url, extras: ["README.md"]]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:dialyxir, "~> 1.0.0-rc.7", only: :dev, runtime: false},
      {:ex_doc, "~> 0.21.0", only: :dev, runtime: false},
      {:excoveralls, "~> 0.12", only: :test},
      {:jason, "~> 1.1.0", only: :test, runtime: false},
      {:phoenix, "~> 1.4.0", only: :test}
    ]
  end
end
