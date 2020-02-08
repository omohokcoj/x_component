defmodule FormInput do
  use X.Component,
    assigns: %{
      :record => map(),
      :name => String.t() | atom(),
      optional(:label) => nil | String.t(),
      optional(:type) => nil | :field | :textarea
    },
    template: ~X"""
    <div class="form-group">
      <label x-unless="label == false">
        {{ label || Macro.camelize(to_string(name)) }}
      </label>
      <input
        x-if="type in [nil, :field]"
        :name="name"
        :value="record[name]"
        class="form-control"
      >
      <textarea
        x-else-if="type == :textarea"
        :name="name"
        class="form-control"
      >{{ record[name] }}</textarea>
    </div>
    """
end
