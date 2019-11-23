defmodule X.ComponentTest do
  use ExUnit.Case

  defmodule Listing do
    import String, only: [reverse: 1]

    use X.Template

    def render(assigns) do
      ~X"""
      <meta scr="as">
      <div asd="asd">1</div>
      <div x-if="false">
        2asdfgh
        ert
      </div>
        <span x-else> 3 </span>
      """
    end

    def test() do
      %{test: true, devo: false}
    end

    def fest() do
      "asd"
    end
  end

  defmodule Hello do
    import String, only: [reverse: 1]
    alias List.Chars

    use X.Component,
      attrs: [
        :message,
        :listing
      ],
      template: ~X"""
      <Listing
        :class="listing"
        :listing="listing"
        :style=[reverse("asd")]
      >
      </Listing>
      """

    def test do
      to_string(Chars.to_charlist())
    end
  end

  test "greets the world" do
    IO.puts(Hello.render(message: "asd", listing: "321"))
  end
end
