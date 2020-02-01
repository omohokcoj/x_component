defmodule Phoenix.Phoenix.Controller.ComponentsTest do
  use ExUnit.Case

  import Plug.Test

  defmodule ExampleLayout do
    use X.Template

    def render("default.html", assigns) do
      {:safe,
       ~X"""
       <div>
         <span>Example Layout</span>
         <X
           :assigns="@assigns"
           :component="@component"
         />
       </div>
       """}
    end
  end

  defmodule ExampleComponent do
    use X.Component,
      assigns: [:test],
      template: ~X"""
      <div>Example {{ test }}</div>
      """
  end

  defmodule ExampleController do
    use Phoenix.Controller, namespace: XTest
    use Phoenix.Controller.Components

    plug :accepts, ~w[html]
    plug :put_layout, {ExampleLayout, :default}

    def index(conn, _params) do
      conn
      |> put_component(ExampleComponent)
      |> render(test: "test")
    end
  end

  test "renders component" do
    conn = ExampleController.call(conn(:get, "/"), ExampleController.init(:index))

    assert conn.resp_body == "<div> <span>Example Layout</span> <div>Example test</div> </div>"
  end
end
