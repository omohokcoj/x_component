defmodule XTest do
  use ExUnit.Case
  doctest X

  defmodule Example do
    use X.Component,
      assigns: %{
        :x => integer()
      },
      template: ~X"""
      <div> {{ x }} </div>
      """
  end

  describe "compile_string/3" do
    test "throws syntax error" do
      assert_raise SyntaxError, fn ->
        X.compile_string!("< test>")
      end

      assert_raise SyntaxError, fn ->
        X.compile_string!("<test")
      end

      assert_raise SyntaxError, fn ->
        X.compile_string!("<div></inv>")
      end

      assert_raise SyntaxError, fn ->
        X.compile_string!("</inv>")
      end
    end

    test "throws compile error" do
      assert_raise CompileError, fn ->
        X.compile_string!("<XTest.Example  />")
      end
    end
  end
end
