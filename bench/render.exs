defmodule XComponentBench do
  use X.Component,
    assigns: [
      :site_title,
      :list
    ],
    template: ~X"""
    <html>
      <head>
        <meta name="keywords">
        <title>{{ site_title }}</title>
      </head>
      <body>
        <div x-for="x <- list">
          <meta :title='x <> "title"'>
          <div class="test">
            Item #{{ x }}
          </div>
        </div>
      </body>
    </html>
    """
end

defmodule EExBench do
  require EEx

  EEx.function_from_string(
    :def,
    :eex,
    """
    <html>
    <head>
      <meta name="keywords">
      <title><%= site_title %></title>
    </head>

    <body>
      <%= for x <- list do %>
        <div>
          <meta title="<%= Plug.HTML.html_escape(x <> "title") %>>
          <div class="test">
            Item #<%= Plug.HTML.html_escape(x) %>
          </div>
        </div>
      <% end %>
    </body>
    </html>
    """,
    [:site_title, :list]
  )
end

defmodule PhoenixBench do
  require EEx

  EEx.function_from_string(
    :def,
    :eex,
    """
    <html>
    <head>
      <meta name="keywords">
      <title><%= site_title %></title>
    </head>

    <body>
      <%= for x <- list do %>
        <div>
          <meta title="<%= x <> "title" %>>
          <div class="test">
            Item #<%= x %>
          </div>
        </div>
      <% end %>
    </body>
    </html>
    """,
    [:site_title, :list],
    engine: Phoenix.HTML.Engine
  )
end

list = Enum.map(1..1000, & to_string(&1))

benchmarks = %{
  "X (iodata)" => fn ->
    XComponentBench.render(%{site_title: "Hello", list: list})
  end,
  "X (string)" => fn ->
    IO.iodata_to_binary(XComponentBench.render(%{site_title: "Hello", list: list}))
  end,
  "EEx (string)" => fn ->
    EExBench.eex("Hello", list)
  end,
  "Phoenix EEx (iodata)" => fn ->
    Phoenix.HTML.Safe.to_iodata(PhoenixBench.eex("Hello", list))
  end,
  "Phoenix EEx (string)" => fn ->
    IO.iodata_to_binary(Phoenix.HTML.Safe.to_iodata(PhoenixBench.eex("Hello", list)))
  end
}

Benchee.run(benchmarks, parallel: 1, warmup: 1, time: 5, print: [fast_warning: false])
