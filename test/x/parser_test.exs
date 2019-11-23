defmodule X.ParserTest do
  use ExUnit.Case
  alias X.Tokenizer
  alias X.Parser

  @template ~s"""
  {{ test }}
  <Description>
    <head>
  <div/>
    <meta content="asd">
    <link src="asd">
    </head>
    <span/>
    <div>
      Test
      {{ test }}
      <div>
        Test
        {{ test }}
        <div>
          Test
          {{ test }}
          {{= test }}
        </div>
      </div>
    </div>
  </Description>
  """

  test "greets the world" do
    tokens = Tokenizer.call(@template)

    Parser.call(tokens) == [
      {{:text_group, {11, 1}, nil},
       [
         {{:tag_output, {11, 1}, 'test ', true}, []},
         {{:tag_text, {1, 2}, '\n', true, true}, []}
       ]},
      {{:tag_start, {14, 2}, 'Description', [], nil, nil, false, false, true},
       [
         {{:text_group, {5, 3}, 'Description'}, [{{:tag_text, {5, 3}, '\n  ', true, true}, []}]},
         {{:tag_start, {11, 3}, 'head', [], nil, nil, false, false, false},
          [
            {{:text_group, {1, 4}, 'head'}, [{{:tag_text, {1, 4}, '\n', true, true}, []}]},
            {{:tag_start, {7, 4}, 'div', [], nil, nil, false, true, false}, []},
            {{:text_group, {5, 5}, 'head'}, [{{:tag_text, {5, 5}, '\n  ', true, true}, []}]},
            {{:tag_start, {22, 5}, 'meta', [{:tag_attr, {21, 5}, 'content', 'asd', false}], nil,
              nil, true, false, false}, []},
            {{:text_group, {5, 6}, 'head'}, [{{:tag_text, {5, 6}, '\n  ', true, true}, []}]},
            {{:tag_start, {18, 6}, 'link', [{:tag_attr, {17, 6}, 'src', 'asd', false}], nil, nil,
              true, false, false}, []},
            {{:text_group, {5, 7}, 'head'}, [{{:tag_text, {5, 7}, '\n  ', true, true}, []}]}
          ]},
         {{:text_group, {5, 8}, 'Description'}, [{{:tag_text, {5, 8}, '\n  ', true, true}, []}]},
         {{:tag_start, {12, 8}, 'span', [], nil, nil, false, true, false}, []},
         {{:text_group, {5, 9}, 'Description'}, [{{:tag_text, {5, 9}, '\n  ', true, true}, []}]},
         {{:tag_start, {10, 9}, 'div', [], nil, nil, false, false, false},
          [
            {{:text_group, {17, 10}, 'div'},
             [
               {{:tag_text, {17, 10}, '\n    Test', true, false}, []},
               {{:tag_text, {9, 11}, '\n    ', true, true}, []},
               {{:tag_output, {19, 11}, 'test ', true}, []},
               {{:tag_text, {9, 12}, '\n    ', true, true}, []}
             ]},
            {{:tag_start, {14, 12}, 'div', [], nil, nil, false, false, false},
             [
               {{:text_group, {21, 13}, 'div'},
                [
                  {{:tag_text, {21, 13}, '\n      Test', true, false}, []},
                  {{:tag_text, {13, 14}, '\n      ', true, true}, []},
                  {{:tag_output, {23, 14}, 'test ', true}, []},
                  {{:tag_text, {13, 15}, '\n      ', true, true}, []}
                ]},
               {{:tag_start, {18, 15}, 'div', [], nil, nil, false, false, false},
                [
                  {{:text_group, {25, 16}, 'div'},
                   [
                     {{:tag_text, {25, 16}, '\n        Test', true, false}, []},
                     {{:tag_text, {17, 17}, '\n        ', true, true}, []},
                     {{:tag_output, {27, 17}, 'test ', true}, []},
                     {{:tag_text, {17, 18}, '\n        ', true, true}, []},
                     {{:tag_output, {28, 18}, 'test ', false}, []},
                     {{:tag_text, {13, 19}, '\n      ', true, true}, []}
                   ]}
                ]},
               {{:text_group, {9, 20}, 'div'}, [{{:tag_text, {9, 20}, '\n    ', true, true}, []}]}
             ]},
            {{:text_group, {5, 21}, 'div'}, [{{:tag_text, {5, 21}, '\n  ', true, true}, []}]}
          ]},
         {{:text_group, {1, 22}, 'Description'}, [{{:tag_text, {1, 22}, '\n', true, true}, []}]}
       ]},
      {{:text_group, {1, 23}, nil}, [{{:tag_text, {1, 23}, '\n', true, true}, []}]}
    ]
  end
end
