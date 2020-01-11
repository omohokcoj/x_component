defmodule X.MixProject do
  use Mix.Project

  def project do
    [
      app: :x_component,
      version: "0.1.0",
      elixir: "~> 1.9",
      deps: deps(),
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

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:dialyxir, "~> 1.0.0-rc.7", only: [:dev], runtime: false}
    ]
  end
end
