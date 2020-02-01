defmodule X.FormatterTest do
  use ExUnit.Case

  defmacro sigil_F({:<<>>, _, [expr]}, _opts) do
    "\n" <> String.trim_trailing(expr)
  end

  defmacro formatted_string() do
    quote do
      var!(template)
      |> X.Tokenizer.call()
      |> X.Parser.call()
      |> X.Formatter.call()
      |> IO.iodata_to_binary()
    end
  end

  describe "call/2" do
    test "formats nested with indentation" do
      template = "<div class='test'><div>test<div>test</div></div>test</div>"

      assert formatted_string() == ~F"""
             <div class="test">
               <div>test
                 <div>test</div>
               </div>test
             </div>
             """
    end

    test "formats multiple attributes with indentation" do
      template = "<div test1='test1' test2='test2'/>"

      assert formatted_string() == ~F"""
             <div
               test1="test1"
               test2="test2"
             />
             """
    end

    test "sorts attributes" do
      template = "<div id='test1' :id='test2' zip=1 abs=2 :zoom=1 :any=2/>"

      assert formatted_string() == ~F"""
             <div
               id="test1"
               :id="test2"
               :any="2"
               :zoom="1"
               abs="2"
               zip="1"
             />
             """
    end

    test "keeps whitespaces in interpolated text" do
      template = "<div> Hello{{message}} world</div>"

      assert formatted_string() == ~F"""
             <div> Hello{{ message }} world</div>
             """
    end

    test "formats comment tag" do
      template = """
      <div><!-- test -->
      test<!-- test -->
      </div>
      """

      assert formatted_string() == ~F"""
             <div>
               <!-- test -->
               test
               <!-- test -->
             </div>
             """
    end

    test "formats output" do
      template = "<div> {{= test}}{{message}}   {{= test }}</div>"

      assert formatted_string() == ~F"""
             <div> {{= test }}{{ message }} {{= test }}</div>
             """
    end

    test "formats elixir code" do
      template = "<div x-for='a<-[1,2,3]' x-if='2+2'> {{= test+2}}</div>"

      assert formatted_string() == ~F"""
             <div
               x-if="2 + 2"
               x-for="a <- [1, 2, 3]"
             > {{= test + 2 }}</div>
             """
    end

    test "keeps indentation in script tags" do
      template = """
      <div>
        <script>
          var a = 1
          if (a == 1) {
            console.log(1)
          }
        </script>
        <style>
          .test {
            color: #ddd;
          }
          .test2 {
            color: #ddd;
          }
        </style>
      </div>
      """

      assert formatted_string() == ~F"""
             <div>
               <script>
                 var a = 1
                 if (a == 1) {
                   console.log(1)
                 }
               </script>
               <style>
                 .test {
                   color: #ddd;
                 }
                 .test2 {
                   color: #ddd;
                 }
               </style>
             </div>
             """
    end
  end
end
