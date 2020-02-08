defmodule X.CompilerTest do
  use ExUnit.Case
  doctest X.Compiler

  def compile(template, opts) do
    template
    |> X.Tokenizer.call()
    |> X.Parser.call()
    |> X.Compiler.call(__ENV__, opts)
  end

  defmodule Example do
    use X.Component,
      assigns: %{
        :x => integer()
      },
      template: ~X"""
      <div> {{ x }} </div>
      """
  end

  defmodule ExampleDecorator do
    use X.Component,
      assigns: %{
        :x => integer()
      },
      template: ~X"""
      <div
        :attrs="@attrs"
        class="btn"
      > {{ x }} </div>
      """
  end

  defmodule ExampleYield do
    use X.Component,
      template: ~X"""
      <div class="btn"> {{ @yield }} </div>
      """
  end

  describe "inline: true" do
    test "compiles component" do
      ast =
        compile(
          """
          <span><X.CompilerTest.Example :x=1 /></span>
          """,
          inline: true
        )

      assert ast ==
               [
                 "<span><div> ",
                 {{:., [line: 1], [{:__aliases__, [line: 1], [:X, :Html]}, :to_safe_iodata]},
                  [line: 1], [1]},
                 " </div></span>"
               ]
    end

    test "merges static attrs" do
      ast =
        compile(
          """
          <span><X.CompilerTest.ExampleDecorator :x=1 class="test" data="test" /></span>
          """,
          inline: true
        )

      assert ast ==
               [
                 "<span><div class=\"btn test\" data=\"test\"> ",
                 {{:., [line: 1], [{:__aliases__, [line: 1], [:X, :Html]}, :to_safe_iodata]},
                  [line: 1], [1]},
                 " </div></span>"
               ]
    end

    test "merges dynamic attrs" do
      ast =
        compile(
          """
          <span><X.CompilerTest.ExampleDecorator :x=1 :class="test" data="test" /></span>
          """,
          inline: true
        )

      assert ast ==
               [
                 "<span><div ",
                 {{:., [line: 1],
                   [{:__aliases__, [line: 1, alias: false], [:X, :Html]}, :attrs_to_iodata]},
                  [line: 1], [[{"class", [{"btn", true}, {{:test, [line: 1], nil}, true}]}]]},
                 " data=\"test\"> ",
                 {{:., [line: 1], [{:__aliases__, [line: 1], [:X, :Html]}, :to_safe_iodata]},
                  [line: 1], [1]},
                 " </div></span>"
               ]
    end

    test "merges assigned attrs" do
      ast =
        compile(
          """
          <span><X.CompilerTest.ExampleDecorator :x=1 :attrs=[class: test()] :class="test" data="test" /></span>
          """,
          inline: true
        )

      assert ast ==
               [
                 "<span><div",
                 {:case, [line: 1],
                  [
                    {:{}, [line: 1],
                     [
                       {{:., [], [{:__aliases__, [alias: false], [:X, :Html]}, :merge_attrs]}, [],
                        [
                          [{"data", "test"}, {"class", {:test, [line: 1], nil}}],
                          [class: {:test, [line: 1], []}]
                        ]},
                       [],
                       [{"class", "btn"}]
                     ]},
                    [
                      do: [
                        {:->, [line: 1],
                         [
                           [
                             {:when, [line: 1],
                              [
                                {:{}, [line: 1],
                                 [
                                   {:attrs_, [line: 1], X.Compiler},
                                   {:base_attrs_, [line: 1], X.Compiler},
                                   {:static_attrs_, [line: 1], X.Compiler}
                                 ]},
                                {:or, [line: 1],
                                 [
                                   {:not, [line: 1],
                                    [
                                      {:in, [line: 1],
                                       [{:attrs_, [line: 1], X.Compiler}, [nil, []]]}
                                    ]},
                                   {:!=, [line: 1], [{:base_attrs_, [line: 1], X.Compiler}, []]}
                                 ]}
                              ]}
                           ],
                           [
                             32,
                             {{:., [line: 1],
                               [{:__aliases__, [line: 1], [:X, :Html]}, :attrs_to_iodata]},
                              [line: 1],
                              [
                                {{:., [line: 1],
                                  [{:__aliases__, [line: 1], [:X, :Html]}, :merge_attrs]},
                                 [line: 1],
                                 [
                                   {:++, [line: 1],
                                    [
                                      {:base_attrs_, [line: 1], X.Compiler},
                                      {:static_attrs_, [line: 1], X.Compiler}
                                    ]},
                                   {:attrs_, [line: 1], X.Compiler}
                                 ]}
                              ]}
                           ]
                         ]},
                        {:->, [line: 1],
                         [[{:_, [line: 1], X.Compiler}], [[32, "class", 61, 34, "btn", 34]]]}
                      ]
                    ]
                  ]},
                 "> ",
                 {{:., [line: 1], [{:__aliases__, [line: 1], [:X, :Html]}, :to_safe_iodata]},
                  [line: 1], [1]},
                 " </div></span>"
               ]
    end

    test "yields component body" do
      ast =
        compile(
          """
          <span><X.CompilerTest.ExampleYield> Hello {{ x }} </X.CompilerTest.ExampleYield></span>
          """,
          inline: true
        )

      assert ast ==
               [
                 "<span><div class=\"btn\"> ",
                 {{:., [line: 1], [{:__aliases__, [line: 1], [:X, :Html]}, :to_safe_iodata]},
                  [line: 1],
                  [
                    [
                      [
                        " Hello ",
                        {{:., [line: 1],
                          [{:__aliases__, [line: 1, alias: false], [:X, :Html]}, :to_safe_iodata]},
                         [line: 1], [{:x, [line: 1], nil}]}
                      ]
                    ]
                  ]},
                 " </div></span>"
               ]
    end

    test "throws error on missing assign" do
      error =
        catch_throw(
          compile(
            """
            <span><X.CompilerTest.Example class="test" /></span>
            """,
            inline: true
          )
        )

      assert error == {:missing_assign, {1, 1}, :x}
    end
  end

  describe "inline: false" do
    test "compiles component" do
      ast =
        compile(
          """
          <span><X.CompilerTest.Example :x=1 /></span>
          """,
          inline: false
        )

      assert ast == [
               "<span>",
               {{:., [line: 1], [Example, :render]}, [line: 1], [{:%{}, [], [x: 1]}]},
               "</span>"
             ]
    end

    test "passes static attrs" do
      ast =
        compile(
          """
          <span><X.CompilerTest.Example :x=1 class="test" /></span>
          """,
          inline: false
        )

      assert ast ==
               [
                 "<span>",
                 {{:., [line: 1], [X.CompilerTest.Example, :render]}, [line: 1],
                  [{:%{}, [], [attrs: [{"class", "test"}], x: 1]}]},
                 "</span>"
               ]
    end

    test "passes assigned attrs" do
      ast =
        compile(
          """
          <span><X.CompilerTest.Example :x=1 :attrs=[class: "demo"] class="test" :class="var" /></span>
          """,
          inline: false
        )

      assert ast ==
               [
                 "<span>",
                 {{:., [line: 1], [X.CompilerTest.Example, :render]}, [line: 1],
                  [
                    {:%{}, [],
                     [
                       attrs:
                         {{:., [], [{:__aliases__, [alias: false], [:X, :Html]}, :merge_attrs]},
                          [],
                          [
                            {{:., [],
                              [{:__aliases__, [alias: false], [:X, :Html]}, :merge_attrs]}, [],
                             [[{"class", "test"}], [{"class", {:var, [line: 1], nil}}]]},
                            [{:class, "demo"}]
                          ]},
                       x: 1
                     ]}
                  ]},
                 "</span>"
               ]
    end

    test "passes assigns" do
      ast =
        compile(
          """
          <span><X.CompilerTest.Example :x=1 :assigns=%{x: 2} /></span>
          """,
          inline: false
        )

      assert ast ==
               [
                 "<span>",
                 {{:., [line: 1], [X.CompilerTest.Example, :render]}, [line: 1],
                  [{:%{}, [line: 1], [x: 2]}]},
                 "</span>"
               ]
    end

    test "compiles dynamic component" do
      ast =
        compile(
          """
          <span><X :component="test" class="test" /></span>
          """,
          inline: false
        )

      assert ast ==
               [
                 "<span>",
                 {{:., [line: 1], [{:test, [line: 1], nil}, :render]}, [line: 1],
                  [{:%{}, [], [attrs: [{"class", "test"}]]}]},
                 "</span>"
               ]
    end

    test "compiles dynamic tag" do
      ast =
        compile(
          """
          <span><X :is="test" /></span>
          """,
          inline: false
        )

      assert ast ==
               [
                 "<span><",
                 {{:., [], [:erlang, :iolist_to_binary]}, [], [{:test, [line: 1], nil}]},
                 "></",
                 {{:., [], [:erlang, :iolist_to_binary]}, [], [{:test, [line: 1], nil}]},
                 "></span>"
               ]
    end

    test "compiles special tag" do
      ast =
        compile(
          """
          <span><X x-if="true">Test</X></span>
          """,
          inline: false
        )

      assert ast ==
               [
                 "<span>",
                 {:if, [line: 1, context: X.Compiler, import: Kernel],
                  [true, [do: "Test", else: []]]},
                 "</span>"
               ]
    end

    test "compiles iterator" do
      ast =
        compile(
          """
          <span><X x-for="a <- [1, 2, 3, 4], a > 3">Test {{ a }}</X></span>
          <span><X x-for="[a <- list]">Test {{ a }}</X></span>
          """,
          inline: false
        )

      assert ast ==
               [
                 "<span>",
                 {:for, [line: 1],
                  [
                    {:<-, [line: 1], [{:a, [line: 1], nil}, [1, 2, 3, 4]]},
                    {:>, [line: 1], [{:a, [line: 1], nil}, 3]},
                    [
                      do: [
                        "Test ",
                        {{:., [line: 1],
                          [{:__aliases__, [line: 1, alias: false], [:X, :Html]}, :to_safe_iodata]},
                         [line: 1], [{:a, [line: 1], nil}]}
                      ],
                      into: []
                    ]
                  ]},
                 "</span> <span>",
                 {:for, [line: 2],
                  [
                    {:<-, [line: 2], [{:a, [line: 2], nil}, {:list, [line: 2], nil}]},
                    [
                      do: [
                        "Test ",
                        {{:., [line: 2],
                          [{:__aliases__, [line: 2, alias: false], [:X, :Html]}, :to_safe_iodata]},
                         [line: 2], [{:a, [line: 2], nil}]}
                      ],
                      into: []
                    ]
                  ]},
                 "</span>"
               ]
    end

    test "compiles dynamic attr" do
      ast =
        compile(
          """
          <span :class="test"/>
          <span :class="test" class="demo"/>
          """,
          inline: false
        )

      assert ast ==
               [
                 "<span",
                 {:case, [],
                  [
                    {:test, [line: 1], nil},
                    [
                      do: [
                        {:->, [], [[true], " class=\"true\""]},
                        {:->, [],
                         [
                           [
                             {:when, [],
                              [
                                {:value, [], X.Compiler},
                                {:not, [context: X.Compiler, import: Kernel],
                                 [
                                   {:in, [context: X.Compiler, import: Kernel],
                                    [{:value, [], X.Compiler}, [nil, false]]}
                                 ]}
                              ]}
                           ],
                           [
                             " class=\"",
                             {{:., [],
                               [
                                 {:__aliases__, [alias: false], [:X, :Html]},
                                 :attr_value_to_iodata
                               ]}, [], [{:value, [], X.Compiler}, "class"]},
                             34
                           ]
                         ]},
                        {:->, [], [[{:_, [], X.Compiler}], []]}
                      ]
                    ]
                  ]},
                 "></span> <span ",
                 {{:., [], [{:__aliases__, [alias: false], [:X, :Html]}, :attrs_to_iodata]}, [],
                  [[{"class", [{{:test, [line: 2], nil}, true}, {"demo", true}]}]]},
                 "></span>"
               ]
    end

    test "compiles condition chain" do
      ast =
        compile(
          """
          <span x-unless="test"/>
          <span x-if="test"/>
          <span x-else-if="test"/>
          <span x-else="test"/>
          """,
          inline: false
        )

      assert ast ==
               [
                 {:if, [line: 1, context: X.Compiler, import: Kernel],
                  [
                    {:__block__, [], [{:!, [line: 1], [{:test, [line: 1], nil}]}]},
                    [do: "<span></span>", else: []]
                  ]},
                 {:if, [line: 2, context: X.Compiler, import: Kernel],
                  [
                    {:test, [line: 2], nil},
                    [
                      do: "<span></span>",
                      else:
                        {:if, [line: 3, context: X.Compiler, import: Kernel],
                         [{:test, [line: 3], nil}, [do: "<span></span>", else: "<span></span>"]]}
                    ]
                  ]}
               ]
    end

    test "compiles text" do
      ast =
        compile(
          """
          <span> Test </span>
          <span>

          Test

          Test

          </span>
          """,
          inline: false
        )

      assert ast == "<span> Test </span> <span> \nTest \nTest </span>"
    end

    test "compiles @assigns" do
      ast =
        compile(
          """
          <span> {{ @assigns }} </span>
          """,
          inline: false
        )

      assert ast == [
               "<span> ",
               {{:., [line: 1],
                 [{:__aliases__, [line: 1, alias: false], [:X, :Html]}, :to_safe_iodata]},
                [line: 1], [{:assigns, [], nil}]},
               " </span>"
             ]
    end

    test "compiles @yield" do
      ast =
        compile(
          """
          <span> {{ @yield }} </span>
          """,
          inline: false
        )

      assert ast == [
               "<span> ",
               {{:., [line: 1],
                 [{:__aliases__, [line: 1, alias: false], [:X, :Html]}, :to_safe_iodata]},
                [line: 1], [{:yield, [], nil}]},
               " </span>"
             ]
    end

    test "compiles @attrs" do
      ast =
        compile(
          """
          <span> {{ @attrs }} </span>
          """,
          inline: false
        )

      assert ast ==
               [
                 "<span> ",
                 {{:., [line: 1],
                   [{:__aliases__, [line: 1, alias: false], [:X, :Html]}, :to_safe_iodata]},
                  [line: 1],
                  [
                    {{:., [line: 1], [{:__aliases__, [line: 1, alias: false], [:Map]}, :get]},
                     [line: 1], [{:assigns, [], nil}, :attrs]}
                  ]},
                 " </span>"
               ]
    end
  end
end
