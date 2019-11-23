defmodule X.Parser do
  @type leaf :: {
          token :: X.Ast.token(),
          children :: [leaf()]
        }

  defguard is_text_token(token) when elem(token, 0) in [:tag_text, :tag_output]

  def call(tokens) do
    parse(tokens, nil, [])
  end

  defp parse(list = [token | _], scope, acc) when is_text_token(token) do
    {children, rest} = parse_text_group(list)
    [{head, _} | _] = children

    parse(rest, scope, [
      {{:text_group, elem(head, 1), scope}, children}
      | acc
    ])
  end

  defp parse([token = {:tag_start, _, _, _, _, _, singleton, selfclosed, _} | tail], scope, acc)
       when singleton or selfclosed do
    parse(tail, scope, [{token, []} | acc])
  end

  defp parse([token = {:tag_start, _, name, _, _, _, _, _, _} | tail], scope, acc) do
    {children, rest} = parse(tail, name, [])

    parse(rest, scope, [{token, children} | acc])
  end

  defp parse([{:tag_end, cur, name} | tail], scope, acc) do
    case scope do
      ^name ->
        {Enum.reverse(acc), tail}

      _ ->
        throw([:error, cur, scope, name])
    end
  end

  defp parse([], _, acc) do
    Enum.reverse(acc)
  end

  defp parse_text_group(list) do
    parse_text_group(list, [])
  end

  defp parse_text_group(list = [token | tail], acc) do
    cond do
      is_text_token(token) ->
        parse_text_group(tail, [{token, []} | acc])

      true ->
        {Enum.reverse(acc), list}
    end
  end

  defp parse_text_group([], acc) do
    {Enum.reverse(acc), []}
  end
end
