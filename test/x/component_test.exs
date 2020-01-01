defmodule X.ComponentTest do
  use ExUnit.Case

  defmodule Listing do
    import String, only: [reverse: 1]

    use X.Template

    def render(assigns, do: yield) do
      ~X"""
      <meta
        :attrs="@attrs"
        scr="as"
      >
      <div asd="asd" />
      <div x-if="false">
        2asdfgh
        ert
      </div>
      <X
        x-else
        :is="test"
      > {{ @listing }} {{  }} </X>
      """
    end

    def test() do
      "di"
    end

    def fest() do
      "asd"
    end
  end

  defmodule Hello do
    import String, only: [reverse: 1]
    alias List.Chars

    use X.Component,
      assigns: %{
        message: String.t(),
        listing: Chars.t()
      },
      template: ~X"""
      <Listing
        :assigns="igns()"
        :attrs=[{"asd", 1}]
        :class="listing"
        style="asd"
      >
        123 {{ @yield }}
      </Listing>
      """

    def igns do
      %{listing: test()}
    end

    def test do
      "asd"
    end
  end

  test "greets the world" do
    IO.puts(Hello.render(%{message: "asd", listing: "321"}, do: "Hello"))
  end
end
