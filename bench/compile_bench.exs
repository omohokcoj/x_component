html_template = """
<html>
<head>
  <meta name="keywords" description="Slime">
  <title>Website Title</title>
  <script>alert('Slime supports embedded javascript!');</script>
</head>

#{
  for(a <- (1..100), do: ~s(
<body>
  <div class="class" id="id">
    <ul>
      <li>1</li>
      <li>2</li>
    </ul>
  </div>
</body>
  ), into: "")
}
</html>
"""

slime_template = """
html
  head
    meta name="keywords" description="Slime"
    title Website Title
    javascript:
      alert('Slime supports embedded javascript!');

""" <> for(a <- (1..100), do: """
  body
    #id.class
      ul
        li 1
        li 2
  """, into: "")

pug_template = """
html
  head
    meta(name="keywords" description="Slime")
    title Website Title
    script alert('Slime supports embedded javascript!');
#{
  for(a <- (1..100), do: ~s(
  body
    #id.class
      ul
        li 1
        li 2
  ), into: "")
}
"""

Benchee.run(%{
    "X" => fn ->
      tokens = X.Tokenizer.call(html_template)
      tree = X.Parser.call(tokens)
      template_ast = X.Compiler.call(tree, __ENV__)
    end,
    "EEx" => fn ->
      EEx.compile_string(html_template)
    end,
    "Slime" => fn ->
      slime = Slime.Renderer.precompile(slime_template)
      EEx.compile_string(slime)
    end,
    "Pug" => fn ->
      pug = Expug.to_eex!(pug_template)
      EEx.compile_string(pug)
    end,
    "Floki" => fn ->
      :floki_mochi_html.parse(html_template)
    end
  },
  parallel: 1,
  warmup: 1,
  time: 1,
  print: [fast_warning: false]
)
