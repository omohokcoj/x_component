defmodule X.MixProject do
  use Mix.Project

  def project do
    [
      app: :x_component,
      version: "0.1.0",
      elixir: "~> 1.9"
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end
end
