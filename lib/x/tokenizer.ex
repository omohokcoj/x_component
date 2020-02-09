defmodule X.Tokenizer do
  @moduledoc """
  X template tokenizer module.
  """

  alias X.Ast

  @whitespaces ' \n\r\t'
  @attr_stop_chars @whitespaces ++ '/>'
  @namechars '.-_:'

  @singleton_tags ~w[
    area base br col embed hr
    img input keygen link meta
    param source track wbr
  ]c

  defguardp is_whitespace(char) when char in @whitespaces
  defguardp is_capital(char) when char >= ?A and char <= ?Z
  defguardp is_lowercase(char) when char >= ?a and char <= ?z
  defguardp is_letter(char) when is_capital(char) or is_lowercase(char)
  defguardp is_digit(char) when char >= ?0 and char <= ?9
  defguardp is_literal(char) when is_letter(char) or is_digit(char)
  defguardp is_namechar(char) when is_literal(char) or char in @namechars

  @doc ~S"""
  Parses given string or charlist into X template tokens.
  See `X.Ast` for tokens type definition.

  ## Example

      iex> X.Tokenizer.call("<div><span class='test'>{{ a }}</span></div>")
      [
        {:tag_start, {1, 1}, 'div', [], nil, nil, false, false, false},
        {:tag_start, {6, 1}, 'span', [{:tag_attr, {12, 1}, 'class', 'test', false}],
         nil, nil, false, false, false},
        {:tag_output, {25, 1}, 'a ', true},
        {:tag_end, {32, 1}, 'span'},
        {:tag_end, {39, 1}, 'div'}
      ]
  """
  @spec call(charlist() | String.t()) :: [Ast.token()]
  def call(html) when is_list(html) do
    tokenize(html, {1, 1})
  end

  def call(html) when is_binary(html) do
    html
    |> :unicode.characters_to_list()
    |> call()
  end

  @spec tokenize(charlist(), Ast.cursor()) :: [Ast.token()]
  defp tokenize('</' ++ tail, {col, row}) do
    {name, list, cur} = extract_tag_end(tail, {col + 2, row})

    token = {:tag_end, {col, row}, name}

    [token | tokenize(list, cur)]
  end

  defp tokenize('{{=' ++ tail, {col, row}) do
    {list, cur} = skip_whitespace(tail, {col + 3, row})
    {data, list, cur} = extract_tag_output(list, cur)

    token = {:tag_output, {col, row}, data, false}

    [token | tokenize(list, cur)]
  end

  defp tokenize('{{' ++ tail, {col, row}) do
    {list, cur} = skip_whitespace(tail, {col + 2, row})
    {data, list, cur} = extract_tag_output(list, cur)

    token = {:tag_output, {col, row}, data, true}

    [token | tokenize(list, cur)]
  end

  defp tokenize('<!' ++ tail, {col, row}) do
    {data, list, cur} = extract_value(tail, {col + 2, row}, '>', nil, false)

    token = {:tag_comment, {col, row}, data}

    [token | tokenize(list, cur)]
  end

  defp tokenize([?<, next | tail], {col, row}) do
    cond do
      is_letter(next) ->
        {token, list, cur} = extract_tag_start([next | tail], {col, row})

        [token | tokenize(list, cur)]

      true ->
        throw({:unexpected_token, {col, row}, next})
    end
  end

  defp tokenize([char | tail], cur = {col, row}) do
    {text, is_blank, list, cur} = extract_tag_text(tail, next_cursor(char, cur))

    token = {:tag_text, {col, row}, [char | text], is_whitespace(char), is_blank}

    [token | tokenize(list, cur)]
  end

  defp tokenize([], _) do
    []
  end

  @spec extract_tag_text(charlist(), Ast.cursor()) ::
          {charlist(), boolean(), charlist(), Ast.cursor()}
  defp extract_tag_text(list, {col, row}) do
    case list do
      [char, next | tail] when char != ?< and [char, next] != '{{' and char != ?\n ->
        {acc, is_blank, rest, cur} = extract_tag_text([next | tail], {col + 1, row})

        {[char | acc], is_blank && is_whitespace(char), rest, cur}

      [char] ->
        {[char], is_whitespace(char), [], {col, row}}

      _ ->
        {[], true, list, {col, row}}
    end
  end

  @spec extract_tag_output(charlist(), Ast.cursor()) ::
          {charlist(), charlist(), Ast.cursor()}
  defp extract_tag_output(list, {col, row}) do
    case list do
      '}}' ++ tail ->
        {[], tail, {col + 2, row}}

      [char, next | tail] ->
        {acc, rest, cur} = extract_tag_output([next | tail], next_cursor(char, {col, row}))

        {[char | acc], rest, cur}

      [char | _] ->
        throw({:unexpected_token, {col, row}, char})
    end
  end

  @spec extract_tag_end(charlist(), Ast.cursor()) :: {charlist(), charlist(), Ast.cursor()}
  defp extract_tag_end(list, {col, row}) do
    {name, rest, cur} = extract_name(list, {col, row})
    {false, rest, cur} = extract_tag_close(rest, cur)

    {name, rest, cur}
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

  @spec extract_name(charlist(), Ast.cursor()) :: {charlist(), charlist(), Ast.cursor()}
  defp extract_name(list = [char | tail], {col, row}) do
    case is_namechar(char) do
      true ->
        {acc, rest, cur} = extract_name(tail, {col + 1, row})

        {[char | acc], rest, cur}

      _ ->
        {[], list, {col, row}}
    end
  end

  defp extract_name([], cur) do
    throw({:unexpected_token, cur, ?\s})
  end

  @spec extract_tag_attributes(
          charlist(),
          Ast.cursor()
        ) ::
          {[Ast.tag_attr()], Ast.tag_condition() | nil, Ast.tag_iterator() | nil, charlist(),
           Ast.cursor()}
  defp extract_tag_attributes(list, cur) do
    {list, {col, row}} = skip_whitespace(list, cur)

    case list do
      [char | _] when char in '/>' ->
        {[], nil, nil, list, cur}

      'x-else-if' ++ tail ->
        cur = {col + 8, row}
        {value, list, cur} = extract_attr_value(tail, cur)
        {acc, _, iterator, rest, cur} = extract_tag_attributes(list, cur)
        {acc, {:elseif, cur, value}, iterator, rest, cur}

      'x-unless' ++ tail ->
        cur = {col + 8, row}
        {value, list, cur} = extract_attr_value(tail, cur)
        {acc, _, iterator, rest, cur} = extract_tag_attributes(list, cur)
        {acc, {:unless, cur, value}, iterator, rest, cur}

      'x-else' ++ tail ->
        cur = {col + 6, row}
        {value, list, cur} = extract_attr_value(tail, cur)
        {acc, _, iterator, rest, cur} = extract_tag_attributes(list, cur)
        {acc, {:else, cur, value}, iterator, rest, cur}

      'x-for' ++ tail ->
        cur = {col + 5, row}
        {value, list, cur} = extract_attr_value(tail, cur)
        {acc, condition, _, rest, cur} = extract_tag_attributes(list, cur)
        {acc, condition, {:for, cur, value}, rest, cur}

      'x-if' ++ tail ->
        {value, list, cur} = extract_attr_value(tail, {col + 4, row})
        {acc, _, iterator, rest, cur} = extract_tag_attributes(list, cur)
        {acc, {:if, cur, value}, iterator, rest, cur}

      _ ->
        {attr, list, cur} = extract_attribute(list, {col, row})
        {acc, condition, iterator, rest, cur} = extract_tag_attributes(list, cur)
        {[attr | acc], condition, iterator, rest, cur}
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
        extract_value([?%, ?{ | rest], {col + 3, row}, '}', ?{, true)

      [?=, ?' | rest] ->
        extract_value(rest, {col + 2, row}, [?'], nil, false)

      '="' ++ rest ->
        extract_value(rest, {col + 2, row}, '"', nil, false)

      '=[' ++ rest ->
        extract_value([?[ | rest], {col + 2, row}, ']', ?[, true)

      [?=, next | rest] when is_literal(next) ->
        extract_value([next | rest], {col + 1, row}, @attr_stop_chars, nil, false)

      [char | _] when is_whitespace(char) or char in '/>' ->
        {[], list, {col, row}}

      [char | _] ->
        throw({:unexpected_token, {col, row}, char})
    end
  end

  @spec extract_value(charlist(), Ast.cursor(), charlist(), nil | integer(), boolean()) ::
          {charlist(), charlist(), Ast.cursor()}
  @spec extract_value(charlist(), Ast.cursor(), charlist(), nil | integer(), boolean(), integer()) ::
          {charlist(), charlist(), Ast.cursor()}
  defp extract_value(list, cur, terminator, continue_char, include_terminator, nesting \\ 0)

  defp extract_value(
         [char | rest],
         {col, row},
         terminator,
         continue_char,
         include_terminator,
         nesting
       ) do
    cur = next_cursor(char, {col, row})

    cond do
      char == continue_char ->
        {acc, rest, cur} =
          extract_value(rest, cur, terminator, continue_char, include_terminator, nesting + 1)

        {[char | acc], rest, cur}

      char in terminator and (nesting == 1 or is_nil(continue_char)) ->
        {(include_terminator && [char]) || [], rest, cur}

      char in terminator ->
        {acc, rest, cur} =
          extract_value(rest, cur, terminator, continue_char, include_terminator, nesting - 1)

        {[char | acc], rest, cur}

      true ->
        {acc, rest, cur} =
          extract_value(rest, cur, terminator, continue_char, include_terminator, nesting)

        {[char | acc], rest, cur}
    end
  end

  defp extract_value([], cur, _, _, _, _) do
    throw({:unexpected_token, cur, ?\n})
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
