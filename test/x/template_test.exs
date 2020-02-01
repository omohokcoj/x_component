defmodule X.TemplateTest do
  use ExUnit.Case

  use X.Template

  describe "~X" do
    test "compiles template ast as string" do
      x = 1

      template = ~X"""
      <div> {{ x }} </div>
      """s

      assert template == "<div> 1 </div>"
    end

    test "compiles template ast as iodata" do
      x = 1

      template = ~X"""
      <div> {{ x }} </div>
      """

      assert template == ["<div> ", "1", " </div>"]
    end
  end

  describe "sigil_X/2" do
    test "compiles template ast as iodata" do
      x = 1

      template = sigil_X("<div> {{ x }} </div>", '')

      assert template == ["<div> ", "1", " </div>"]
    end
  end
end
