defmodule Button do
  use X.Component,
    assigns: [
      :href
    ],
    template: ~X"""
    <button
      :href="href"
      class="test"
    >
      {{= yield }}
      In publishing and graphic design, Lorem ipsum is a placeholder text commonly used to demonstrate the visual form of a document or a typeface without relying on meaningful content.
    </button>
    """
end

defmodule Text do
  use X.Component,
    assigns: [
      :message
    ],
    template: ~X"""
    <section class="test">
      <Button :href="message">
        {{ message }}
      </Button>
      {{ message }}
      <br>
      {{ message }}
      In publishing and graphic design, Lorem ipsum is a placeholder text commonly used to demonstrate the visual form of a document or a typeface without relying on meaningful content.
    </section>
    """
end

defmodule XComponent do
  use X.Component,
    assigns: [
      :list
    ],
    template: ~X"""
    <div x-for="a <- list">
      <Button :href="a">
        {{ a }}
      </Button>
      <Text :message="a" />

      <Button :href="a">
        {{ a }}
      </Button>
      <Text :message="a" />

      <Button :href="a">
        {{ a }}
      </Button>
      <Text :message="a" />

      <Button :href="a">
        {{ a }}
      </Button>
      <Text :message="a" />

      <Button :href="a">
        {{ a }}
      </Button>
      <Text :message="a" />

      <Button :href="a">
        {{ a }}
      </Button>
      <Text :message="a" />
    </div>
    """
end

defmodule PhoenixBench do
  require EEx

  EEx.function_from_string(
    :def,
    :button,
    """
    <button href="<%= href %>" class="test">
      <%= yield %>
      In publishing and graphic design, Lorem ipsum is a placeholder text commonly used to demonstrate the visual form of a document or a typeface without relying on meaningful content.
    </button>
    """,
    [:href, :yield],
    engine: Phoenix.HTML.Engine
  )

  EEx.function_from_string(
    :def,
    :text,
    """
    <section class="test">
      <%= button(message, message) %>
      <%= message %>
      <br>
      <%= message %>
      In publishing and graphic design, Lorem ipsum is a placeholder text commonly used to demonstrate the visual form of a document or a typeface without relying on meaningful content.
    </section>
    """,
    [:message],
    engine: Phoenix.HTML.Engine
  )

  EEx.function_from_string(
    :def,
    :render,
    """
    <%= for a <- list do %>
      <div>
        <%= button(a, a) %>
        <%= text(a) %>

        <%= button(a, a) %>
        <%= text(a) %>

        <%= button(a, a) %>
        <%= text(a) %>

        <%= button(a, a) %>
        <%= text(a) %>

        <%= button(a, a) %>
        <%= text(a) %>

        <%= button(a, a) %>
        <%= text(a) %>
      </div>
    <% end %>
    """,
    [:list],
    engine: Phoenix.HTML.Engine
  )
end

list = Enum.map(1..20000, &to_string(&1))

benchmarks = %{
  "X (iodata)" => fn ->
    XComponent.render(%{list: list})
  end,
  "X (string)" => fn ->
    IO.iodata_to_binary(XComponent.render(%{list: list}))
  end,
  "Phoenix EEx (iodata)" => fn ->
    Phoenix.HTML.Safe.to_iodata(PhoenixBench.render(list))
  end,
  "Phoenix EEx (string)" => fn ->
    IO.iodata_to_binary(Phoenix.HTML.Safe.to_iodata(PhoenixBench.render(list)))
  end
}

Benchee.run(benchmarks, parallel: 1, warmup: 1, time: 5, print: [fast_warning: false])
