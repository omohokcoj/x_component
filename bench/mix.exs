defmodule XBench.MixProject do
  use Mix.Project

  def project do
    [
      app: :x_bench,
      version: "0.1.0",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases()
    ]
  end

  defp aliases() do
    [
      "bench.compile": ["run compile.exs"],
      "bench.render": ["run render.exs"],
      "bench.render_nested": ["run render_nested.exs"],
      "bench.render_inline": ["run render_inline.exs"]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:benchee, "~> 1.0"},
      {:benchee_html, "~> 1.0"},
      {:calliope, ">= 0.0.0"},
      {:expug, ">= 0.0.0"},
      {:floki, ">= 0.0.0"},
      {:phoenix, ">= 0.0.0"},
      {:phoenix_html, ">= 0.0.0"},
      {:poison, ">= 0.0.0"},
      {:slime, ">= 0.0.0"},
      {:x_component, ">= 0.0.0", path: "../", override: true}
    ]
  end
end
