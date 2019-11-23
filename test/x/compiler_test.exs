defmodule X.CompilerTest do
  use ExUnit.Case
  alias X.Tokenizer
  alias X.Parser

  @template """
  <Description>
    <span />
    <div>
      Test
      {{ test }}
    </div>
  </Description>
  """
end
