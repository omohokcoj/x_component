defmodule XComponentBench  do
  use X.Component,
    assigns: [
      :site_title, :arr
    ],
    template: ~X"""
    <html>
    <head>
      <meta name="keywords" description="Slime">
      <title>{{ site_title }}</title>
      <script>alert('Slime supports embedded javascript!');</script>
    </head>

    <body>
      <div class="class" id="id">
        <ul>
          <li x-for="x <- arr">{{ x }}</li>
        </ul>
      </div>
    </body>
    </html>
    """
end

defmodule EExBench do
  require EEx

  EEx.function_from_string :def, :eex, """
  <html>
  <head>
    <meta name="keywords" description="Slime">
    <title><%= site_title %></title>
  </head>
  <body>
    <div class="class" id="id">
      <ul>
      <%= for x <- arr do %>
        <li><%= x %></li>
      <% end %>
      </ul>
    </div>
  </body>
  </html>
  """, [:site_title, :arr]
end

defmodule SlimeBench do
  require Slime

  Slime.function_from_string :def, :slime, """
  html
    head
      meta name="keywords" description="Slime"
      title = site_title
      javascript:
        alert('Slime supports embedded javascript!');
    body
      #id.class
        ul
          = Enum.map arr, fn x ->
            li = x
  """, [:site_title, :arr]
end

Benchee.run(%{
    "X" => fn ->
      XComponentBench.render(%{site_title: "Hello", arr: [1,2,3]})
    end,
    "EEx" => fn ->
      EExBench.eex("Hello", [1,2,3])
    end,
    "Slime" => fn ->
      SlimeBench.slime("Hello", [1,2,3])
    end
  },
  parallel: 1,
  warmup: 1,
  time: 1,
  print: [fast_warning: false]
)
