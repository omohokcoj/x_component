template_size = 100

eex_template =
  for(_ <- 1..template_size, into: "") do
    ~s(
<body>
  <div id="message">Bench</div>
  <div class="class" id="id">
    <ul>
      <li class="test">1</li>
      <li data="<%= data %>">
        <%= message %>
      </li>
    </ul>
  </div>
</body>)
  end

x_template =
  for(_ <- 1..template_size, into: "") do
    ~s(
<body>
  <div id="message">Bench</div>
  <div class="class" id="id">
    <ul>
      <li class="test">1</li>
      <li :data="data">
        {{ message }}
      </li>
    </ul>
  </div>
</body>)
  end

slim_template =
  for(_ <- 1..template_size, into: "") do
    ~s(
body
  #message Bench
  #id.class
    ul
      li.test 1
      li data=data
        = message)
  end

pug_template =
  for(_ <- 1..template_size, into: "") do
    ~s[
body
  #message Bench
  #id.class
    ul
      li.test 1
      li(data=data) = message]
  end

haml_template =
  for(_ <- 1..template_size, into: "") do
    ~s[
%body
  #message Bench
  #id.class
    %ul
      %li.test 1
      %li(data=data)
        = message]
  end

benchmarks = %{
  "X (compiler)" => fn ->
    tokens = X.Tokenizer.call(x_template)
    tree = X.Parser.call(tokens)
    X.Compiler.call(tree)
  end,
  "X (parser)" => fn ->
    tokens = X.Tokenizer.call(x_template)
    X.Parser.call(tokens)
  end,
  "EEx (html)" => fn ->
    EEx.compile_string(eex_template)
  end,
  "Slime (slim)" => fn ->
    slime = Slime.Renderer.precompile(slim_template)
    EEx.compile_string(slime)
  end,
  "Expug (pug)" => fn ->
    pug = Expug.to_eex!(pug_template)
    EEx.compile_string(pug)
  end,
  "Calliope (haml)" => fn ->
    haml = Calliope.Render.precompile(haml_template)
    EEx.compile_string(haml)
  end,
  "Floki/Mochi (html parser)" => fn ->
    :floki_mochi_html.parse(x_template)
  end
}

Benchee.run(benchmarks, parallel: 1, warmup: 3, time: 5, print: [fast_warning: false])
