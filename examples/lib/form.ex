defmodule Form do
  use X.Component,
    assigns: %{
      :action => String.t()
    },
    template: ~X"""
    <form :action="action">
      {{= yield }}
      <Button
        class="btn-block btn-primary"
        type="submit"
      > Submit
      </Button>
    </form>
    """
end
