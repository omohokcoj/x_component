defmodule X.TokenizerTest do
  use ExUnit.Case
  doctest X.Tokenizer

  alias X.Tokenizer

  describe "call/1" do
    test "tokenizes component" do
      template = "<div><Test :test='1'/></div>"

      assert Tokenizer.call(template) == [
               {:tag_start, {1, 1}, 'div', [], nil, nil, false, false, false},
               {:tag_start, {6, 1}, 'Test', [{:tag_attr, {12, 1}, 'test', '1', true}], nil, nil,
                false, true, true},
               {:tag_end, {23, 1}, 'div'}
             ]
    end

    test "tokenizes singleton tag" do
      template = "<div><hr test='1'></div>"

      assert Tokenizer.call(template) ==
               [
                 {:tag_start, {1, 1}, 'div', [], nil, nil, false, false, false},
                 {:tag_start, {6, 1}, 'hr', [{:tag_attr, {10, 1}, 'test', '1', false}], nil, nil,
                  true, false, false},
                 {:tag_end, {19, 1}, 'div'}
               ]
    end

    test "tokenizes comment" do
      template = "<div><!-- test --></div>"

      assert Tokenizer.call(template) ==
               [
                 {:tag_start, {1, 1}, 'div', [], nil, nil, false, false, false},
                 {:tag_comment, {6, 1}, '-- test --'},
                 {:tag_end, {19, 1}, 'div'}
               ]
    end

    test "tokenizes attributes" do
      template = """
      <div
        :a=%{test: 1}
        :b=["test"]
        :c="test"
        :d='test'
        f='test'
        g="test"
        h=123
        i
      />
      """

      assert Tokenizer.call(template) ==
               [
                 {:tag_start, {1, 1}, 'div',
                  [
                    {:tag_attr, {3, 2}, 'a', '%{test: 1}', true},
                    {:tag_attr, {3, 3}, 'b', '["test"]', true},
                    {:tag_attr, {3, 4}, 'c', 'test', true},
                    {:tag_attr, {3, 5}, 'd', 'test', true},
                    {:tag_attr, {3, 6}, 'f', 'test', false},
                    {:tag_attr, {3, 7}, 'g', 'test', false},
                    {:tag_attr, {3, 8}, 'h', '123', false},
                    {:tag_attr, {3, 9}, 'i', [], false}
                  ], nil, nil, false, true, false},
                 {:tag_text, {3, 10}, '\n', true, true}
               ]
    end

    test "tokenizes directives" do
      template = """
      <div x-if="2 + 2 == 4" x-for="a <- [1, 2, 3], a == 2">
        {{ a }}
      </div>
      <div x-else="2"/>
      <div x-unless="2"/>
      <div x-else-if=true/>
      """

      assert Tokenizer.call(template) ==
               [
                 {:tag_start, {1, 1}, 'div', [], {:if, {54, 1}, '2 + 2 == 4'},
                  {:for, {54, 1}, 'a <- [1, 2, 3], a == 2'}, false, false, false},
                 {:tag_text, {55, 1}, '\n  ', true, true},
                 {:tag_output, {3, 2}, 'a ', true},
                 {:tag_text, {10, 2}, '\n', true, true},
                 {:tag_end, {1, 3}, 'div'},
                 {:tag_text, {7, 3}, '\n', true, true},
                 {:tag_start, {1, 4}, 'div', [], {:else, {16, 4}, '2'}, nil, false, true, false},
                 {:tag_text, {18, 4}, '\n', true, true},
                 {:tag_start, {1, 5}, 'div', [], {:unless, {18, 5}, '2'}, nil, false, true,
                  false},
                 {:tag_text, {20, 5}, '\n', true, true},
                 {:tag_start, {1, 6}, 'div', [], {:elseif, {20, 6}, 'true'}, nil, false, false,
                  false},
                 {:tag_text, {21, 6}, '\n', true, true}
               ]
    end

    test "tokenizes text interpolation" do
      template = """
      <div>
        {{ a }} test {{= b }}
      </div>
      """

      assert Tokenizer.call(template) ==
               [
                 {:tag_start, {1, 1}, 'div', [], nil, nil, false, false, false},
                 {:tag_text, {6, 1}, '\n  ', true, true},
                 {:tag_output, {3, 2}, 'a ', true},
                 {:tag_text, {10, 2}, ' test ', true, false},
                 {:tag_output, {16, 2}, 'b ', false},
                 {:tag_text, {24, 2}, '\n', true, true},
                 {:tag_end, {1, 3}, 'div'},
                 {:tag_text, {7, 3}, '\n', true, true}
               ]
    end

    test "throws error when tag is not closed" do
      template = """
      <div
        {{ a }}
      </div>
      """

      assert catch_throw(Tokenizer.call(template)) == {:unexpected_token, {3, 2}, ?{}

      template = """
      <div>
        {{ a }}
      </div
      """

      assert catch_throw(Tokenizer.call(template)) == {:unexpected_token, {6, 3}, ?\n}
    end

    test "throws error when tag contains invalid name" do
      template = """
      < asd>
        {{ a }}
      </div>
      """

      assert catch_throw(Tokenizer.call(template)) == {:unexpected_token, {1, 1}, ?\s}
    end

    test "throws error when interpolation is not closed" do
      template = """
      <div>
        {{ a
      </div>
      """

      assert catch_throw(Tokenizer.call(template)) == {:unexpected_token, {7, 3}, ?\n}
    end

    test "throws error when attribute syntax is invalid" do
      template = """
      <div :test= test/>
      """

      assert catch_throw(Tokenizer.call(template)) == {:unexpected_token, {11, 1}, ?=}
    end
  end
end
