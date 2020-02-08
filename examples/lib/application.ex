defmodule ExampleApplication do
  use Application

  defmodule Web do
    import Plug.Conn

    def init(options) do
      options
    end

    def call(conn, _opts) do
      book = %{id: 1, title: "Example", body: "Example Body", type: "fiction"}
      assigns = %{conn: %{host: "https://example.com"}, book: book}

      conn
      |> Plug.Logger.call(Plug.Logger.init([]))
      |> put_resp_content_type("text/html")
      |> send_resp(200, Index.render(assigns))
    end
  end

  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    children = [
      {Plug.Cowboy, scheme: :http, plug: Web, options: [port: 4001]}
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
