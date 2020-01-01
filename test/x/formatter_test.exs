defmodule X.FormatterTest do
  use ExUnit.Case

  @template """
  <!DOCTYPE html>
  <div  x-for="a <- [123,123]" asd="asd" id="asd" :asd="asd"  x-if="true">
  <div asd="asd" asd="asd">
    <div asd="asd">
  asd {{ 2+2}}asd
  asd


    </div>
  <meta asd="12" >
  <span asd="12" asdads="asd" />
  <asd asd="12">{{ asd }}</asd>
  <asd asd="12">
  {{ asd }}
  </asd>
  <asd asd="12" asdad="asd">
  {{ asd }}
  </asd>
  <asd asd="12" asd="12"> asd {{asd  }}
  </asd>
  <asd asd="12">
  asd
  </asd>
  </div>
  </div>
  """

  test "greets the world" do
    tokens = X.Tokenizer.call(@template)
    tree = X.Parser.call(tokens)
    doc = X.Formatter.call(tree)
    assert doc == ~s(
<!DOCTYPE html>
<div
  x-if="true"
  x-for="a <- [123, 123]"
  id="asd"
  :asd="asd"
  asd="asd"
>
  <div
    asd="asd"
    asd="asd"
  >
    <div asd="asd">
      asd {{ 2 + 2 }}asd
      asd
    </div>
    <meta asd="12">
    <span
      asd="12"
      asdads="asd"
    />
    <asd asd="12">{{ asd }}</asd>
    <asd asd="12">
      {{ asd }}
    </asd>
    <asd
      asd="12"
      asdad="asd"
    >
      {{ asd }}
    </asd>
    <asd
      asd="12"
      asd="12"
    > asd {{ asd }}
    </asd>
    <asd asd="12">
      asd
    </asd>
  </div>
</div>)
  end
end
