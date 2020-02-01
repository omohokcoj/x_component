defmodule X.ParserTest do
  use ExUnit.Case

  alias X.{Tokenizer, Parser}

  describe "call/1" do
    test "returns ast" do
      template = """
      <div>
        <div class="test">
          {{ test }} test
        </div>
        <div class="test">
          <span x-if="true">
            {{ test }} test
            test
          </span>
        </div>
      </div>
      """

      tokens = Tokenizer.call(template)

      assert Parser.call(tokens) == [
               {{:tag_start, {1, 1}, 'div', [], nil, nil, false, false, false},
                [
                  {{:text_group, {6, 1}, 'div'}, [{{:tag_text, {6, 1}, '\n  ', true, true}, []}]},
                  {{:tag_start, {3, 2}, 'div', [{:tag_attr, {8, 2}, 'class', 'test', false}], nil,
                    nil, false, false, false},
                   [
                     {{:text_group, {21, 2}, 'div'},
                      [
                        {{:tag_text, {21, 2}, '\n    ', true, true}, []},
                        {{:tag_output, {5, 3}, 'test ', true}, []},
                        {{:tag_text, {15, 3}, ' test', true, false}, []},
                        {{:tag_text, {20, 3}, '\n  ', true, true}, []}
                      ]}
                   ]},
                  {{:text_group, {9, 4}, 'div'}, [{{:tag_text, {9, 4}, '\n  ', true, true}, []}]},
                  {{:tag_start, {3, 5}, 'div', [{:tag_attr, {8, 5}, 'class', 'test', false}], nil,
                    nil, false, false, false},
                   [
                     {{:text_group, {21, 5}, 'div'},
                      [{{:tag_text, {21, 5}, '\n    ', true, true}, []}]},
                     {{:tag_start, {5, 6}, 'span', [], {:if, {22, 6}, 'true'}, nil, false, false,
                       false},
                      [
                        {{:text_group, {23, 6}, 'span'},
                         [
                           {{:tag_text, {23, 6}, '\n      ', true, true}, []},
                           {{:tag_output, {7, 7}, 'test ', true}, []},
                           {{:tag_text, {17, 7}, ' test', true, false}, []},
                           {{:tag_text, {22, 7}, '\n      test', true, false}, []},
                           {{:tag_text, {11, 8}, '\n    ', true, true}, []}
                         ]}
                      ]},
                     {{:text_group, {12, 9}, 'div'},
                      [{{:tag_text, {12, 9}, '\n  ', true, true}, []}]}
                   ]},
                  {{:text_group, {9, 10}, 'div'}, [{{:tag_text, {9, 10}, '\n', true, true}, []}]}
                ]},
               {{:text_group, {7, 11}, nil}, [{{:tag_text, {7, 11}, '\n', true, true}, []}]}
             ]
    end

    test "throws error when tag is not closed" do
      template = """
      <div>test</ivd>
      """

      tokens = Tokenizer.call(template)

      assert catch_throw(Parser.call(tokens)) == {:unexpected_tag, {10, 1}, 'div', 'ivd'}
    end
  end
end
