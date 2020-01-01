defmodule X.Tokenizer do
  alias X.Ast

  @whitespace ' \n\r\t'
  @namechar '.-_:'

  @singleton_tags ~w[
    area base br col embed hr
    img input keygen link meta
    param source track wbr
  ]c

  defguard is_whitespace(char) when char in @whitespace
  defguard is_capital(char) when char >= ?A and char <= ?Z
  defguard is_lowercase(char) when char >= ?a and char <= ?z
  defguard is_letter(char) when is_capital(char) or is_lowercase(char)
  defguard is_digit(char) when char >= ?0 and char <= ?9
  defguard is_literal(char) when is_letter(char) or is_digit(char)
  defguard is_namechar(char) when is_literal(char) or char in @namechar

  @spec call(charlist() | String.t()) :: [Ast.token()]
  def call(html) when is_list(html) do
    tokenize(html, {1, 1}, [])
  end

  def call(html) when is_binary(html) do
    html
    |> Kernel.to_charlist()
    |> call()
  end

  @spec tokenize(charlist(), Ast.cursor(), [Ast.token()]) :: [Ast.token()]
  defp tokenize([], _col, acc) do
    Enum.reverse(acc)
  end

  defp tokenize('</' ++ tail, {col, row}, acc) do
    {token, list, cur} = extract_tag_end(tail, {col, row})

    tokenize(list, cur, [token | acc])
  end

  defp tokenize('{{=' ++ tail, {col, row}, acc) do
    {list, cur} = skip_whitespace(tail, {col + 3, row})
    {data, list, cur} = extract_tag_output(list, cur)

    token = {:tag_output, {col, row}, data, false}

    tokenize(list, cur, [token | acc])
  end

  defp tokenize('{{' ++ tail, {col, row}, acc) do
    {list, cur} = skip_whitespace(tail, {col + 2, row})
    {data, list, cur} = extract_tag_output(list, cur)

    token = {:tag_output, {col, row}, data, true}

    tokenize(list, cur, [token | acc])
  end

  defp tokenize('<!' ++ tail, {col, row}, acc) do
    {data, list, cur} = extract_value(tail, {col + 2, row}, '>', false)

    token = {:tag_comment, {col, row}, data}

    tokenize(list, cur, [token | acc])
  end

  defp tokenize([?<, next | tail], {col, row}, acc) do
    cond do
      is_letter(next) ->
        {token, list, cur} = extract_tag_start([next | tail], {col, row})

        tokenize(list, cur, [token | acc])

      true ->
        throw({:unexpected_token, {col, row}, next})
    end
  end

  defp tokenize([char | tail], cur = {col, row}, acc) do
    {text, is_blank, list, cur} = extract_tag_text(tail, next_cursor(char, cur))

    token = {:tag_text, {col, row}, [char | text], is_whitespace(char), is_blank}

    tokenize(list, cur, [token | acc])
  end

  @spec extract_tag_text(charlist(), Ast.cursor(), charlist()) ::
          {charlist(), boolean(), charlist(), Ast.cursor()}
  defp extract_tag_text(list, {col, row}, acc \\ [], is_blank \\ true) do
    case list do
      [char, next | tail] when char != ?< and [char, next] != '{{' and char != ?\n ->
        extract_tag_text(
          [next | tail],
          {col + 1, row},
          [char | acc],
          is_blank && is_whitespace(char)
        )

      [char] ->
        {Enum.reverse([char | acc]), is_blank && is_whitespace(char), [],
         next_cursor(char, {col, row})}

      _ ->
        {Enum.reverse(acc), is_blank, list, {col, row}}
    end
  end

  @spec extract_tag_output(charlist(), Ast.cursor(), charlist()) ::
          {charlist(), charlist(), Ast.cursor()}
  defp extract_tag_output(list, {col, row}, acc \\ []) do
    case list do
      '}}' ++ tail ->
        {Enum.reverse(acc), tail, {col + 2, row}}

      [char, next | tail] ->
        extract_tag_output([next | tail], next_cursor(char, {col, row}), [char | acc])

      [char | _] ->
        throw({:unexpected_token, {col, row}, char})
    end
  end

  @spec extract_tag_end(charlist(), Ast.cursor()) :: {Ast.tag_end(), charlist(), Ast.cursor()}
  defp extract_tag_end(list, {col, row}) do
    {name, list, cur} = extract_name(list, {col + 2, row})
    {false, list, cur} = extract_tag_close(list, cur)

    {{:tag_end, {col, row}, name}, list, cur}
  end

  @spec extract_tag_start(charlist(), Ast.cursor()) :: {Ast.tag_start(), charlist(), Ast.cursor()}
  defp extract_tag_start(list, {col, row}) do
    {name, list, cur} = extract_name(list, {col + 1, row})
    {attrs, condition, iterator, list, cur} = extract_tag_attributes(list, cur)
    {is_selfclosed, list, cur} = extract_tag_close(list, cur)

    is_component =
      case name do
        [char | _] when is_capital(char) -> true
        _ -> false
      end

    {
      {:tag_start, {col, row}, name, attrs, condition, iterator, name in @singleton_tags,
       is_selfclosed, is_component},
      list,
      cur
    }
  end

  @spec extract_name(charlist(), Ast.cursor(), charlist()) ::
          {charlist(), charlist(), Ast.cursor()}
  defp extract_name(list = [char | rest], {col, row}, acc \\ []) do
    cond do
      is_namechar(char) -> extract_name(rest, {col + 1, row}, [char | acc])
      true -> {Enum.reverse(acc), list, {col, row}}
    end
  end

  @spec extract_tag_attributes(
          charlist(),
          Ast.cursor(),
          [Ast.tag_attr()],
          Ast.tag_condition() | nil,
          Ast.tag_iterator() | nil
        ) ::
          {[Ast.tag_attr()], Ast.tag_condition() | nil, Ast.tag_iterator() | nil, charlist(),
           Ast.cursor()}
  defp extract_tag_attributes(list, cur, attrs \\ [], condition \\ nil, iterator \\ nil) do
    {list, {col, row}} = skip_whitespace(list, cur)

    case list do
      [char | _] when char in '/>' ->
        {Enum.reverse(attrs), condition, iterator, list, {col, row}}

      'x-elseif' ++ tail ->
        cur = {col + 8, row}
        {value, list, cur} = extract_attr_value(tail, cur)
        extract_tag_attributes(list, cur, attrs, {:elseif, cur, value}, iterator)

      'x-unless' ++ tail ->
        cur = {col + 8, row}
        {value, list, cur} = extract_attr_value(tail, cur)
        extract_tag_attributes(list, cur, attrs, {:unless, cur, value}, iterator)

      'x-else' ++ tail ->
        cur = {col + 6, row}
        {value, list, cur} = extract_attr_value(tail, cur)
        extract_tag_attributes(list, cur, attrs, {:else, cur, value}, iterator)

      'x-for' ++ tail ->
        cur = {col + 5, row}
        {value, list, cur} = extract_attr_value(tail, cur)
        extract_tag_attributes(list, cur, attrs, condition, {:for, cur, value})

      'x-if' ++ tail ->
        cur = {col + 4, row}
        {value, list, cur} = extract_attr_value(tail, cur)
        extract_tag_attributes(list, cur, attrs, {:if, cur, value}, iterator)

      _ ->
        {attr, list, cur} = extract_attribute(list, {col, row})
        extract_tag_attributes(list, cur, [attr | attrs], condition, iterator)
    end
  end

  @spec extract_attribute(charlist(), Ast.cursor()) :: {Ast.tag_attr(), charlist(), Ast.cursor()}
  defp extract_attribute(list, {col, row}) do
    {is_dynamic, {name, list, cur}} =
      case list do
        [?: | rest] ->
          {true, extract_name(rest, {col + 1, row})}

        [char | _] when is_namechar(char) ->
          {false, extract_name(list, {col, row})}

        [char | _] ->
          throw({:unexpected_token, {col, row}, char})
      end

    {value, list, cur} = extract_attr_value(list, cur)

    {list, cur} = skip_whitespace(list, cur)

    {{:tag_attr, {col, row}, name, value, is_dynamic}, list, cur}
  end

  @spec extract_attr_value(charlist(), Ast.cursor()) :: {charlist(), charlist(), Ast.cursor()}
  defp extract_attr_value(list, {col, row}) do
    case list do
      '=%{' ++ rest ->
        extract_value([?%, ?{ | rest], {col + 3, row}, '}', true)

      [?=, ?' | rest] ->
        extract_value(rest, {col + 2, row}, [?'], false)

      '="' ++ rest ->
        extract_value(rest, {col + 2, row}, '"', false)

      '=[' ++ rest ->
        extract_value([?[ | rest], {col + 2, row}, ']', true)

      '={' ++ rest ->
        extract_value([?{ | rest], {col + 2, row}, '}', true)

      [?=, next | rest] when is_literal(next) ->
        extract_value([next | rest], {col + 1, row}, @whitespace, false)

      [char | _] when is_whitespace(char) or char in '/>' ->
        {[], list, {col, row}}

      [char | _] ->
        throw({:unexpected_token, {col, row}, char})
    end
  end

  @spec extract_value(charlist(), Ast.cursor(), charlist(), boolean(), charlist()) ::
          {charlist(), charlist(), Ast.cursor()}
  defp extract_value([char | rest], {col, row}, terminator, include_terminator, acc \\ []) do
    cur = next_cursor(char, {col, row})

    cond do
      char not in terminator ->
        extract_value(rest, cur, terminator, include_terminator, [char | acc])

      true ->
        case include_terminator do
          true ->
            {Enum.reverse([char | acc]), rest, cur}

          _ ->
            {Enum.reverse(acc), rest, cur}
        end
    end
  end

  @spec extract_tag_close(charlist(), Ast.cursor()) :: {boolean(), charlist(), Ast.cursor()}
  defp extract_tag_close(list, {col, row}) do
    case list do
      '/>' ++ rest -> {true, rest, {col + 2, row}}
      [?> | rest] -> {false, rest, {col + 1, row}}
      [char | _] -> throw({:unexpected_token, {col, row}, char})
    end
  end

  @spec skip_whitespace(charlist(), Ast.cursor()) :: {charlist(), Ast.cursor()}
  defp skip_whitespace(list, {col, row}) do
    case list do
      [?\n | rest] ->
        skip_whitespace(rest, {1, row + 1})

      [char | rest] when char in ' \r\t' ->
        skip_whitespace(rest, {col + 1, row})

      _ ->
        {list, {col, row}}
    end
  end

  @spec next_cursor(integer(), Ast.cursor()) :: Ast.cursor()
  defp next_cursor(char, {col, row}) do
    case char do
      ?\n -> {1, row + 1}
      _ -> {col + 1, row}
    end
  end
end
