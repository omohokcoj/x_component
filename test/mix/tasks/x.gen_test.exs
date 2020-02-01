defmodule Mix.Tasks.X.GenTest do
  use ExUnit.Case

  import ExUnit.CaptureIO

  def read_tmp(file) do
    path = Path.expand("tmp/#{file}", File.cwd!())

    File.read!(path)
  end

  test "creates new file" do
    File.rm_rf!(Path.expand("tmp", File.cwd!()))

    assert capture_io(fn ->
             Mix.Tasks.X.Gen.run(["User.Show"])
           end) == "Generated X.Components.User.Show\n"

    assert read_tmp("user/show.ex") == """
           defmodule X.Components.User.Show do
             use X.Template

             use X.Component,
               assigns: %{
               },
               template: ~X"\""
               "\""
           end
           """
  end

  test "doesn't override existing file" do
    path = Path.expand("tmp", File.cwd!())

    File.mkdir_p!(path)
    File.write!(path <> "/user.ex", "test")

    assert capture_io(:stderr, fn ->
             Mix.Tasks.X.Gen.run(["User"])
           end) =~ "tmp/user.ex already exists"
  end
end
