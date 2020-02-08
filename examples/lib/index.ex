defmodule Index do
  use X.Component,
    assigns: %{
      :conn => map(),
      :book => map()
    },
    template: ~X"""
    <!doctype html>
    <html lang="en">
      <head>
        <meta charset="utf-8">
        <meta
          content="width=device-width, initial-scale=1, shrink-to-fit=no"
          name="viewport"
        >
        <link
          crossorigin="anonymous"
          href="https://maxcdn.bootstrapcdn.com/bootstrap/4.0.0/css/bootstrap.min.css"
          integrity="sha384-Gn5384xqQ1aoWXA+058RXPxPg6fy4IWvTNh0E263XmFcJlSAwiGgFAW/dAiS6JXm"
          rel="stylesheet"
        >
        <title>Hello, world!</title>
      </head>
      <body>
        <div class="container">
          <Breadcrumbs
            :crumbs=[
              %{to: :root, params: [], title: "Home", active: false},
              %{to: :form, params: [], title: "Form", active: true}
            ]
            data-breadcrumbs
          />
          <Form :action="update_action(book)">
            <FormInput
              :label='"Title"'
              :name=":title"
              :record="book"
            />
            <FormInput
              :name=":body"
              :record="book"
              :type=":textarea"
            />
            <RadioGroup
              :name=":type"
              :options="book_type_options()"
              :record="book"
            />
          </Form>
        </div>
      </body>
    </html>
    """

  def book_type_options() do
    ["fiction", "business", "tech"]
  end

  def update_action(book) do
    "/book/" <> to_string(book.id)
  end
end
