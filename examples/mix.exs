defmodule XBench.MixProject do
  use Mix.Project

  def project do
    [
      app: :x_examples,
      version: "0.1.0",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases()
    ]
  end

  def application do
    [mod: {ExampleApplication, []}]
  end

  defp aliases() do
    [
      render: ["run example.exs"]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:x_component, ">= 0.0.0", path: "../", override: true},
      {:cowboy, "~> 1.0.0"},
      {:plug_cowboy, "~> 1.0"},
      {:plug, "~> 1.8"}
    ]
  end
end
