defmodule X.HtmlTest do
  use ExUnit.Case
  doctest X.Html

  alias X.Html

  describe "merge_attrs/2" do
    test "returns merged attrs" do
      attrs1 = %{
        "class" => ["btn", "btn-default"],
        "data-time" => "1999-01-01",
        "href" => "https://www.example.com",
        "style" => [{"color", "#fff"}, {"display", true}]
      }

      attrs2 = [
        {"class", "btn-lg"},
        {"href", "https://www.test.com"},
        {"style", [{"color", "#aaa"}, {"display", false}, {"font", "test"}]},
        "itemprop"
      ]

      assert Html.merge_attrs(attrs1, attrs2) == [
               {"style", [{"display", false}, {"color", "#aaa"}, {"font", "test"}]},
               {"href", "https://www.test.com"},
               {"data-time", "1999-01-01"},
               {"class", [{"btn-default", true}, {"btn", true}, {"btn-lg", true}]},
               {"itemprop", true}
             ]
    end
  end

  describe "attrs_to_iodata/1" do
    test "returns iodata" do
      attrs1 = %{
        "class" => ["btn", "btn-default"],
        "data-time" => ~D[1999-01-01],
        "href" => "https://www.example.com",
        "json" => %{"test" => 1},
        "test" => false,
        "style" => [{"color", "#fff"}, {"display", true}, {"demo", false}]
      }

      assert IO.iodata_to_binary(Html.attrs_to_iodata(attrs1)) ==
               ~s(class="btn btn-default" data-time="1999-01-01" href="https://www.example.com" json="{&quot;test&quot;:1}" style="color: #fff; display")
    end
  end

  describe "attr_value_to_iodata/1" do
    test "converts to \"true\" when `true`" do
      assert Html.attr_value_to_iodata(true) == "true"
    end

    test "converts float to iodata" do
      assert Html.attr_value_to_iodata(1.100) == '1.1'
    end

    test "converts integer to iodata" do
      assert Html.attr_value_to_iodata(12) == "12"
    end

    test "converts DateTime to iodata" do
      assert Html.attr_value_to_iodata(
               DateTime.from_naive!(~N[2016-05-24 13:26:08.003], "Etc/UTC")
             ) == "2016-05-24 13:26:08.003Z"
    end
  end

  describe "to_safe_iodata/1" do
    test "escapes characters" do
      assert IO.iodata_to_binary(
               Html.attr_value_to_iodata("""
               <div>"'&</div>
               """)
             ) == "&lt;div&gt;&quot;&#39;&amp;&lt;/div&gt;\n"
    end
  end
end
