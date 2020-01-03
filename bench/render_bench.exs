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
      </ul>
    </div>
  </body>
  </html>
  """, [:site_title, :arr], [engine: Phoenix.HTML.Engine]
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
  """, [:site_title, :arr]
end

IO.puts Macro.to_string(EEx.compile_string("""
  <html>
  <head>
    <meta name="keywords" description="Slime">
    <title><%= site_title %></title>
  </head>
  <body>
    <div class="class" id="id">
      <ul>
      </ul>
    </div>
  </body>
  </html>
  """, [line: 1] ++ [engine: Phoenix.HTML.Engine]))

IO.puts Code.format_string!(Macro.to_string(X.compile_string!("""
<html>
<head>
  <meta name="keywords" description="Slime">
  <title>{{ site_title }}</title>
  <script>alert('Slime supports embedded javascript!');</script>
</head>

<body>
  <div class="class" id="id">
    <ul>
    </ul>
  </div>
</body>
</html>
""")))

arr = Enum.map((1..100000), & to_string(&1))
Benchee.run(%{
    "X" => fn ->
      XComponentBench.render(%{site_title: "Hello", arr: arr})
    end,
    "EEx" => fn ->
       Phoenix.HTML.Safe.to_iodata EExBench.eex("Hello", arr)
    end,
    "Slime" => fn ->
      SlimeBench.slime("Hello", arr)
    end
  },
  parallel: 1,
  warmup: 1,
  time: 1,
  print: [fast_warning: false]
)
