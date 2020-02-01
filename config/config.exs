use Mix.Config

config :x_component,
  compile_inline: true,
  json_library: Jason,
  root_path: "tmp",
  root_module: "X.Components",
  generator_template: """
    use X.Template
  """

config :phoenix, :json_library, Jason
