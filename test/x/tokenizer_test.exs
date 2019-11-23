defmodule X.TokenizerTest do
  use ExUnit.Case
  alias X.Tokenizer

  @template ~s"""
  <X
    :if="listing.id > 1"
    :component=Listing.Description
    :listing=listing
  />
  <Listing.Description
    :for="l <- listings"
    :listing=listing
    :color=%{blue: 1}
    :state={blue, 1}
  />
  <h3 :class="test"/>
  <span
    style="color: 1"
    :class=[{:bold, true}]
    :width=[bold: true]
   > {{ formatted_title(listing.title) }}
     {{= formatted_title(listing.title) }}
      asd
      asd
   </span>
  """

  test "greets the world" do
    assert Tokenizer.call(@template) ==
             [
               {:tag_start, {1, 1}, 'X',
                [
                  {:tag_attr, {3, 2}, 'if', 'listing.id > 1', true},
                  {:tag_attr, {3, 3}, 'component', 'Listing.Description', true},
                  {:tag_attr, {3, 4}, 'listing', 'listing', true}
                ], nil, nil, false, true, true},
               {:tag_text, {3, 5}, '\n', true, true},
               {:tag_start, {1, 6}, 'Listing.Description',
                [
                  {:tag_attr, {3, 7}, 'for', 'l <- listings', true},
                  {:tag_attr, {3, 8}, 'listing', 'listing', true},
                  {:tag_attr, {3, 9}, 'color', '%{blue: 1}', true},
                  {:tag_attr, {3, 10}, 'state', '{blue, 1}', true}
                ], nil, nil, false, true, true},
               {:tag_text, {3, 11}, '\n', true, true},
               {:tag_start, {1, 12}, 'h3', [{:tag_attr, {5, 12}, 'class', 'test', true}], nil,
                nil, false, true, false},
               {:tag_text, {20, 12}, '\n', true, true},
               {:tag_start, {1, 13}, 'span',
                [
                  {:tag_attr, {3, 14}, 'style', 'color: 1', false},
                  {:tag_attr, {3, 15}, 'class', '[{:bold, true}]', true},
                  {:tag_attr, {3, 16}, 'width', '[bold: true]', true}
                ], nil, nil, false, false, false},
               {:tag_text, {3, 17}, ' ', true, true},
               {:tag_output, {4, 17}, 'formatted_title(listing.title) ', true},
               {:tag_text, {40, 17}, '\n   ', true, true},
               {:tag_output, {4, 18}, 'formatted_title(listing.title) ', false},
               {:tag_text, {41, 18}, '\n    asd', true, false},
               {:tag_text, {8, 19}, '\n    asd', true, false},
               {:tag_text, {8, 20}, '\n ', true, true},
               {:tag_end, {2, 21}, 'span'},
               {:tag_text, {9, 21}, '\n', true, true}
             ]
  end
end
