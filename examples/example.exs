use X.Template

book = %{id: 1, title: "Example", body: "Example Body", type: "fiction"}
assigns = %{conn: %{host: "https://example.com"}, book: book}

File.write!("index.html", Index.render(assigns))
