defmodule Mix.Tasks.X.FormatTest do
  use ExUnit.Case

  def in_tmp(function) do
    path = Path.expand("tmp", File.cwd!())
    File.rm_rf!(path)
    File.mkdir_p!(path)
    File.cd!(path, function)
  end

  test "formats the given files" do
    in_tmp(fn ->
      File.write!("a.ex", """
      defmodule Example do
        use X.Component,
          template: ~X"\""
            <div> example<span/> <hr> </div>
          "\""
      end
      """)

      Mix.Tasks.X.Format.run(["a.ex"])

      assert File.read!("a.ex") == """
             defmodule Example do
               use X.Component,
                 template: ~X"\""
                 <div> example
                   <span />
                   <hr>
                 </div>
                 "\""
             end
             """
    end)
  end

  test "uses inputs and configuration from --dot-formatter" do
    in_tmp(fn ->
      File.write!("custom_formatter.exs", """
      [
        inputs: ["a.ex"]
      ]
      """)

      File.write!("a.ex", """
      defmodule Example do
        use X.Component,
          template: ~X"\""
            <div> {{ foo 1 }}
            <span/> <hr> </div>
          "\""
      end
      """)

      Mix.Tasks.X.Format.run(["--dot-formatter", "custom_formatter.exs"])

      assert File.read!("a.ex") == """
             defmodule Example do
               use X.Component,
                 template: ~X"\""
                 <div> {{ foo(1) }}
                   <span />
                   <hr>
                 </div>
                 "\""
             end
             """
    end)
  end
end
