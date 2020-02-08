defmodule RouterLink do
  use X.Component,
    assigns: %{
      :to => atom(),
      optional(:params) => nil | Keyword.t() | map()
    },
    template: ~X"""
    <a
      :attrs="@attrs"
      :href="fake_router(@conn, to, params)"
    >
      {{ yield }}
    </a>
    """

  def fake_router(conn, path, params) do
    params = Enum.map(params || [], fn {k, v} -> Enum.join([k, v], "=") end)

    case params do
      [] ->
        "#{conn.host}/#{path}"

      _ ->
        "#{conn.host}/#{path}?#{Enum.join(params)}"
    end
  end
end
