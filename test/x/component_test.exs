defmodule X.ComponentTest do
  use ExUnit.Case

  defmodule AComponent do
    use X.Component,
      assigns: %{
        required(:message) => String.t(),
        optional(:demo) => boolean()
      },
      template: ~X"""
      <div>
        {{ message }} {{ @yield }}{{ demo }}
      </div>
      """
  end

  defmodule BComponent do
    import String, only: [reverse: 1], warn: false

    use X.Component,
      assigns: %{
        message: String.t()
      },
      template: ~X"""
      <div
        :attrs="@attrs"
        :class="b(message)"
        class="a"
      > {{ reverse(message) }} </div>
      """

    def b(_message) do
      "b"
    end
  end

  defmodule DComponent do
    use X.Component,
      assigns: [:conn],
      template: ~X"""
      <AComponent :message="conn.message">
        {{ yield }}
      </AComponent>
      Test
      <BComponent
        :attrs=[class: "e"]
        :class='"d"'
        :message="conn.message"
        class="c"
      />
      """
  end

  describe "template_ast/1" do
    test "returns ast" do
      assert AComponent.template_ast() ==
               [
                 "<div> ",
                 {{:., [line: 12],
                   [{:__aliases__, [line: 12, alias: false], [:X, :Html]}, :to_safe_iodata]},
                  [line: 12], [{:message, [line: 12], X.ComponentTest.AComponent}]},
                 " ",
                 {{:., [line: 12],
                   [{:__aliases__, [line: 12, alias: false], [:X, :Html]}, :to_safe_iodata]},
                  [line: 12], [{:yield, [], X.ComponentTest.AComponent}]},
                 {{:., [line: 12],
                   [{:__aliases__, [line: 12, alias: false], [:X, :Html]}, :to_safe_iodata]},
                  [line: 12], [{:demo, [line: 12], X.ComponentTest.AComponent}]},
                 " </div>"
               ]
    end
  end

  describe "assigns/1" do
    test "returns assigns list" do
      assert AComponent.assigns() == [{:message, true}, {:demo, false}]
    end
  end

  describe "template/1" do
    test "returns assigns list" do
      assert AComponent.template() == "<div>\n  {{ message }} {{ @yield }}{{ demo }}\n</div>\n"
    end
  end

  describe "render/2" do
    test "returns rendered iodata" do
      iodata =
        DComponent.render %{conn: %{message: "Demo"}} do
          "Test"
        end

      assert iodata == [
               "<div> ",
               "Demo",
               " ",
               "Test",
               [],
               " </div>\nTest <div",
               [32, ["class", '="', ["a", " ", ["b", " ", ["c", " ", ["d", " ", "e"]]]], '"']],
               "> ",
               "omeD",
               " </div>"
             ]
    end
  end

  describe "render_to_string/2" do
    test "returns rendered string" do
      assert DComponent.render_to_string(%{conn: %{message: "Demo"}}) ==
               "<div> Demo  </div>\nTest <div class=\"a b c d e\"> omeD </div>"
    end
  end
end
