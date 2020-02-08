defmodule Button do
  use X.Component,
    template: ~X"""
    <button
      :attrs="@attrs"
      class="btn"
    > {{= yield }}
    </button>
    """
end
