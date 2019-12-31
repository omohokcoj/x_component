if Code.ensure_compiled?(Phoenix.Controller) do
  defmodule Phoenix.Controller.Components do
    defmacro __using__(opts \\ []) do
      quote do
        import unquote(__MODULE__),
          only: [
            put_component: 2,
            put_components_module: 2
          ]

        components_module =
          Keyword.get(
            unquote(opts),
            :components_module,
            unquote(__MODULE__).components_for_controller(__MODULE__)
          )

        plug :put_components_module, components_module
        plug :put_component
      end
    end

    def component(conn) do
      case conn do
        %{assigns: %{component: component}} when not is_nil(component) ->
          component

        %{private: %{phoenix_action: phoenix_action}} ->
          Module.concat(components_module(conn), Macro.camelize(to_string(phoenix_action)))
      end
    end

    def components_module(conn) do
      case conn do
        %{assigns: %{components_module: components_module}} when not is_nil(components_module) ->
          components_module

        %{private: %{phoenix_controller: phoenix_controller}} ->
          components_for_controller(phoenix_controller)
      end
    end

    def put_component(conn, module \\ []) do
      component = if(module == [], do: component(conn), else: module)

      Plug.Conn.assign(conn, :component, component)
    end

    def put_components_module(conn, module \\ []) do
      components_module = if(module == [], do: components_module(conn), else: module)

      conn
      |> Plug.Conn.assign(:components_module, components_module)
      |> Plug.Conn.assign(:component, nil)
      |> put_component()
    end

    def components_for_controller(module) do
      module
      |> to_string()
      |> String.replace("Controller", "s")
      |> String.split(".")
      |> List.insert_at(2, Components)
      |> Module.concat()
    end
  end
end
