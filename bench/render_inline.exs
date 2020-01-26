defmodule Button do
  use X.Component,
    assigns: [
      :href
    ],
    template: ~X"""
    <button
      :attrs="@attrs"
      :href="href"
      class="btn"
    >
      {{= yield }}
    </button>
    """
end

defmodule XComponent do
  use X.Template

  def render_inline(%{link: link}) do
    unquote(
      X.compile_string!(
        Enum.map((1..200), fn _ ->
          """
          <Button :href="link" class="btn-primary">
            Submit
          </Button>
          """
        end) |> IO.iodata_to_binary(),
        __ENV__,
        inline: true
      )
    )
  end

  def render(%{link: link}) do
    unquote(
      X.compile_string!(
        Enum.map((1..200), fn _ ->
          """
          <Button :href="link" class="btn-primary">
            Submit
          </Button>
          """
        end) |> IO.iodata_to_binary(),
        __ENV__,
        inline: false
      )
    )
  end
end

defmodule PhoenixBench do
  require EEx

  EEx.function_from_string(
    :def,
    :button,
    """
    <button href="<%= href %>" class="test <%= class %>">
      <%= yield %>
    </button>
    """,
    [:href, :class, :yield],
    engine: Phoenix.HTML.Engine
  )

  EEx.function_from_string(
    :def,
    :render,
    Enum.map((1..200), fn _ ->
      """
      <%= button(link, "btn-primary", "Hello") %>
      """
    end) |> IO.iodata_to_binary(),
    [:link],
    engine: Phoenix.HTML.Engine
  )
end

link = "example.com"

benchmarks = %{
  "X function (iodata)" => fn ->
    XComponent.render(%{link: link})
  end,
  "X function (string)" => fn ->
    IO.iodata_to_binary(XComponent.render(%{link: link}))
  end,
  "X inline (iodata)" => fn ->
    XComponent.render_inline(%{link: link})
  end,
  "X inline (string)" => fn ->
    IO.iodata_to_binary(XComponent.render_inline(%{link: link}))
  end,
  "Phoenix EEx (iodata)" => fn ->
    Phoenix.HTML.Safe.to_iodata(PhoenixBench.render(link))
  end,
  "Phoenix EEx (string)" => fn ->
    IO.iodata_to_binary(Phoenix.HTML.Safe.to_iodata(PhoenixBench.render(link)))
  end
}

Benchee.run(benchmarks, parallel: 1, warmup: 1, time: 1, print: [fast_warning: false])
