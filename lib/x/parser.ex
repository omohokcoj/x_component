defmodule X.Parser do
  alias X.Ast

  defguard is_text_token(token) when elem(token, 0) in [:tag_text, :tag_output]

  @spec call([Ast.token()]) :: [Ast.leaf()]
  def call(tokens) do
    {result, _} = parse(tokens, nil, [])

    result
  end

  @spec parse([Ast.token()], charlist() | nil, [Ast.leaf()]) :: {[Ast.leaf()], [Ast.token()]}
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
        {:lists.reverse(acc), tail}

      _ ->
        throw({:unexpected_tag, cur, scope, name})
    end
  end

  defp parse([token = {:tag_comment, _, _} | tail], scope, acc) do
    parse(tail, scope, [{token, []} | acc])
  end

  defp parse([], _, acc) do
    {:lists.reverse(acc), []}
  end

  @spec parse_text_group([Ast.token()]) :: {[Ast.leaf()], [Ast.token()]}
  defp parse_text_group([token | tail]) when is_text_token(token) do
    {acc, rest} = parse_text_group(tail)

    {[{token, []} | acc], rest}
  end

  defp parse_text_group(list) do
    {[], list}
  end
end
