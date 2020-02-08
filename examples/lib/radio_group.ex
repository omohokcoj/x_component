defmodule RadioGroup do
  import Macro, only: [camelize: 1], warn: false

  use X.Component,
    assigns: %{
      :record => String.t(),
      :options => [String.t()],
      :name => String.t() | atom()
    },
    template: ~X"""
    <div class="form-group">
      <X x-for="option <- options">
        <input
          :checked="record[name] == option"
          :name="name"
          :value="option"
          type="radio"
        > {{ camelize(option) }}
        <br>
      </X>
    </div>
    """
end
