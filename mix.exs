defmodule X.MixProject do
  use Mix.Project

  def project do
    [
      app: :x_template,
      version: "0.1.0",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
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
      {:dialyxir, "~> 1.0.0-rc.7", only: [:dev], runtime: false},
      {:floki, "~> 0.23.0", only: :dev},
      {:benchee, "~> 1.0", only: :dev},
      {:slime, "~> 1.2", only: :dev},
      {:expug, "~> 0.9", only: :dev},
      {:phoenix, ">= 0.0.0", only: :dev},
      {:plug, ">= 0.0.0"},
      {:temple, "~> 0.4.0", only: :dev}
    ]
  end
end
