# X.Component

Component-based HTML templates for Elixir/Phoenix, inspired by Vue.<br/>
Zero-dependency. Framework/library agnostic. Optimized for [Phoenix](#phoenix-integration) and Gettext.

![x_component](examples/example.gif?raw=true)

## Installation

```elixir
def deps do
  [
    {:x_component, "~> 0.1.0"}
  ]
end
```

## Features

[↳](#template-syntax) Declarative HTML template syntax close to Vue.<br/>
[↳](https://github.com/omohokcoj/x_component/blob/master/test/x_test.exs#L16) Compile time errors and warnings.<br/>
[↳](#assigns) Type checks with dialyzer specs.<br/>
[↳](#template-formatter) Template code formatter.<br/>
[↳](#inline-compilation) Inline, context-aware components.<br/>
[↳](#smart-attributes-merge) Smart attributes merge.<br/>
[↳](#decorator-components) Decorator components.<br/>
[↳](#performance-and-benchmarks) Fast compilation and rendering.<br/>
[↳](#phoenix-integration) Optimized for Gettext/Phoenix/ElixirLS.<br/>
[↳](#generator) Component generator task.

## Template Syntax

See more examples [here](https://github.com/omohokcoj/x_component/tree/master/examples/lib).

```vue
~X"""
<body>
  <!-- Body -->
  <div class="container">
    <Breadcrumbs
      :crumbs=[
        %{to: :root, params: [], title: "Home", active: false},
        %{to: :form, params: [], title: "Form", active: true}
      ]
      data-breadcrumbs
    />
    <Form :action='"/book/" <> to_string(book.id)'>
      {{ @message }}
      <FormInput
        :label='"Title"'
        :name=":title"
        :record="book"
      />
      <FormInput
        :name=":body"
        :record="book"
        :type=":textarea"
      />
      <RadioGroup
        :name=":type"
        :options=["fiction", "bussines", "tech"]
        :record="book"
      />
    </Form>
  </div>
</body>
"""
```

### Tags

#### Static

```vue
<div>
  <meta item="example">
  <span />
</div>
```

#### Dynamic

```vue
<X :is="tag_name" />
```

### Interpolations

#### Safe

```vue
<div>{{ message }}</div>
```

#### Unsafe

```vue
<div>{{= html_string }}</div>
```

### Attributes

#### Static

```vue
<button class="d-flex" data-item="1" />
```

#### Dynamic

```vue
<input :class="[active: item.active]" class="form" data-item="1">
```

```vue
<input :class="item.classes" class="form" data-item="1">
```

```vue
<input :attrs=%{"class" => %{"active" => item.classes, "form" => true}, "data-item" => 1}>
```

### Directives

#### x-for

`x-for` is compiled into Elixir `for` list comprehensions.

```vue
<ul>
  <li x-for="i <- [1, 2, 3, 4], i > 2">{{ i }}</li>
</ul>
```

#### x-if, x-else, x-else-if, x-unless

```vue
<div x-unless="is_nil(day)">
  <span x-if="day == 1">Today</span>
  <span x-else-if="day == 2">Tomorrow</span>
  <span x-else>In the future</span>
<div>
```

### Comments

```vue
<!-- Example -->
```

## Components

### Assigns

Assigns can be defined using Elixir typespecs syntax:

```elixir
defmodule Example do
  use X.Component,
    assigns: %{
      :conn => Conn.Plug.t(),
      required(:book) => map(),
      optional(:label) => nil | false | String.t(),
    },
    template: ~X"""
    <div....
```

By default all assigns are required. Optional assigns can be defined with `optional`
map key typespec.

`:asng="expr"` dynamic attribute syntax is used to pass assigns to the component:

```vue
<Example :conn="conn" :book="book" />
```

Also, assigns can be passed as a `map` via the `:assigns` dynamic attr:

```vue
<Example :assigns=%{conn: conn, book: book} />
```

Assigns can be invoked on the template as local variables:

```vue
<div>{{ book.title }}</div>
```

All assigns can be fetched on the template via `@assigns` macro syntax.

```vue
<div>{{ inspect(@assigns) }}</div>
```

### Dynamic components

Component can be rendered dynamicaly from Elixir expresion using special `X` tag with `:component` attribute:

```vue
<X :component="component_module" />
```

### Decorator components

A simple decorator component would look like:

```elixir
defmodule Form do
  use X.Component,
    assigns: %{
      :action => String.t(),
      :method => String.t() | atom()
    },
    template: ~X"""
    <form
      :attrs="@attrs"
      :action="action"
      :method="method"
      class="base-form"
    > {{= yield }}
    </form>
    """
end
```

`:attrs="@attrs"` is used to specify which HTML tag should be decorated (in Vue it's set to the root tag implicitly).

```elixir
defmodule Index do
  use X.Component,
    template: ~X"""
    <Form
      :action='"/books"'
      :method='"get"'
      class="example-class"
    >
      <label>Title</label>
      <input name="title">
    </Form>
    """
end
```

Nested nodes are passed to the `yield` variable of the child component.<br/>
It's important to use the unsafe (`{{=`) interpolation with `yield` to avoid HTML escaping.

Decorator components are fast due to the inline compilation.

### Inline compilation

By default, all components are rendered using the `inline` method.
It means that instead of rendering nested components with a render function it inserts
nested components AST into the parent component AST.
This approach allows to optimize parent component AST for faster rendering.
Decorator component example from the previous paragraph will be compiled entirely into Elixir
string in compile time:

```elixir
iex> Index.template_ast()
"<form action=\"/books\" method=\"get\" class=\"base-form example-class\"> <label>Title</label> <input name=\"title\"> </form>"
```

Also, makes it possible to fetch parent component assigns from the child component
via `@var` syntax, without passing the assigns explicitly.

```vue
  <a
    :href="router(@conn, to, params)"
  > {{ yield }}
  </a>
```

Inline compilation method is not supported by dynamic components.

Compilation method can be adjusted via the application configs:

```elixir
config :x_component,
  compile_inline: true
```

### Smart attributes merge

X template compiler uses special rules for `style` and `class` attributes. Instead of overriding
values it merges them into a list of classes and styles:

```elixir
defmodule Button do
  use X.Component,
    assigns: %{
      optional(:submit) => nil | boolean()
    },
    template: ~X"""
    <button :attrs="@attrs" :class=[submit: submit] class="btn">Submit</button>
    """
end
```

```vue
~X"""
<Button
  :submit="true"
  :class=[{"btn-default", true}]
  class="btn-lg"
/>
"""
```

```html
<button class="btn submit btn-lg btn-default">Submit</button>
```

Style or class can be removed by passing `false` to the child component:

```vue
~X"""
<Button
  :submit="true"
  :class=[{"btn", false}, {"x-btn", true}]
  class="btn-lg"
/>
"""
```

```html
<button class="submit btn-lg x-btn">Submit</button>
```

## Template formatter

Formatter task uses settings from `.formatter.exs` by default.
All project files can be formatted with:

```elixir
mix x.formatter
```

Also, formatter task can be used to format a specific file:

```elixir
mix x.formatter path/to/file.ex
```

## Generator

New component files can be generated with:

```elixir
mix x.gen Users.Show
```

Generator settings can be adjusted via `:x_component` application configs:

```elixir
config :x_component,
  root_path: "lib/app_web/components",
  root_module: "AppWeb.Components",
  generator_template: """
    use X.Template
  """
```

## Phoenix integration

* Remove `:phoenix_html` library *(optional)*.
* Add `:x_component` application configs to the `config/config.exs`:

```elixir
config :x_component,
  json_library: Jason,
  root_module: AppWeb.Components,
  root_path: "lib/app_web/components"
```

* Disable html `format_encoders` in `configs.exs`:

```elixir
config :phoenix, :format_encoders, html: false
```

* Create application layout module:

```elixir
defmodule MyApp.Components.Layouts.App do
  use Uncovered.Web, :component

  def render(_, assigns) do
    ~X"""
    <!DOCTYPE html>
    <html lang="en">
      <head>
        ...
      </head>
      <body>
        <X
          :assigns="@assigns"
          :component="@component"
        />
      </body>
    </html>
    """
  end
end
```

* Set layout (in the `router.ex` or in the controller):

```elixir
  pipeline :browser do
    plug :put_layout, {MyApp.Components.Layouts.App, :default}
    ...
  end
```

* Add `use Phoenix.Controller.Components` to your controller or to all controllers
via the macro in `my_app_web.ex`:

```elixir
  def controller do
    quote do
      use Phoenix.Controller, namespace: Uncovered
      use Phoenix.Controller.Components
      ...
    end
  end
```

* Specify components root module for the controller *(optional)*:

```elixir
defmodule MyAppWeb.HomeController do
  use MyAppWeb, :controller

  plug :put_components_module, MyApp.Components.Root
```

* Specify page components for the controller action *(optional)*:

```elixir
defmodule MyApp.ChatController do
  use MyAppWeb, :controller

  def index(conn, _params) do
    conn
    |> put_component(MyApp.Components.Chat)
    |> render()
  end
end
```

`put_components_module` and `put_component` are optional because `Phoenix.Controller.Components`
uses controller and action names to find a component:

```elixir
MyAppWeb.UserController.show => MyAppWeb.Components.Users.Show
MyAppWeb.HomeController.index => MyAppWeb.Components.Homes.Index
```

## Performance and Benchmarks

### Rendering

X templates HTML rendering shows slightly better results than EEx with `Phoenix.HTML.Engine`.
It was achieved due to safe/unsafe interpolation syntax (instead of `{:safe, ...}` tuples) and due to more compact HTML output with trimmed whitespaces (example [here](https://raw.githubusercontent.com/omohokcoj/x_component/master/examples/index.html)).
However, X templates show a significantly faster rendering of nested components
(templates in case of EEx) due to the inline components compilation:

```
Comparison:
X inline (iodata)          20.38 K
X inline (string)          14.48 K - 1.41x slower +19.99 μs
Phoenix EEx (iodata)        7.52 K - 2.71x slower +83.99 μs
Phoenix EEx (string)        6.43 K - 3.17x slower +106.39 μs
```

### Compilation

X templates compile ~2 times slower than EEx templates because it requires to parse the whole
HTML into the template AST (see `X.Ast`) and compile it back to Elixir AST.
However, X templates are much faster than other Elixir HTML template implementations:

```
Comparison:
Floki/Mochi (html parser)        385.79
X (parser)                       357.78 - 1.08x slower +0.20 ms
EEx (html)                       314.95 - 1.22x slower +0.58 ms
X (compiler)                     152.93 - 2.52x slower +3.95 ms
Calliope (haml)                   23.83 - 16.19x slower +39.37 ms
Slime (slim)                       2.27 - 170.23x slower +438.65 ms
Expug (pug)                      0.0836 - 4614.95x slower +11959.75 ms
```

See all benchmarks [here](https://github.com/omohokcoj/x_component/tree/master/bench).

## TODO

- [ ] Live view integration
- [ ] Components cache
- [ ] Syntax highlight plugins

### Vim hack

Syntax highlight via Vue plugin can be enabled by adding the following line to the `vim-elixir/syntax/elixir.vim`:

```vim
syntax include @VUE syntax/vue.vim
syntax region elixirXTemplateSigil matchgroup=elixirSigilDelimiter keepend start=+\~X\z("""\)+ end=+^\s*\z1+ skip=+\\"+ contains=@VUE fold
```

## Issue/Pull Request?

Yes/Please

## License

MIT
