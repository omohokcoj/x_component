defmodule X.Ast do
  @moduledoc """
  Contains X template AST type definitions and functions to work with the AST.
  """

  @type cursor() :: {
          column :: integer(),
          row :: integer()
        }

  @type tag_attr() :: {
          :tag_attr,
          cursor(),
          name :: charlist(),
          value :: charlist(),
          is_dynamic :: boolean()
        }

  @type tag_condition() :: {
          condition :: :if | :else | :elseif | :unless,
          cursor :: cursor(),
          value :: charlist()
        }

  @type tag_iterator() :: {
          iterator :: :for,
          cursor :: cursor(),
          value :: charlist()
        }

  @type tag_comment() :: {
          :tag_comment,
          cursor :: cursor(),
          value :: charlist()
        }

  @type tag_start() :: {
          :tag_start,
          cursor :: cursor(),
          name :: charlist(),
          attributes :: [tag_attr()],
          condition :: tag_condition(),
          iterator :: tag_iterator(),
          is_singleton :: boolean(),
          is_selfclosed :: boolean(),
          is_component :: boolean()
        }

  @type tag_end() :: {
          :tag_end,
          cursor :: cursor(),
          name :: charlist()
        }

  @type tag_text() :: {
          :tag_text,
          cursor :: cursor(),
          value :: charlist(),
          is_leading_whitespace :: boolean(),
          is_blank :: boolean()
        }

  @type tag_output() :: {
          :tag_output,
          cursor :: cursor(),
          value :: charlist(),
          is_html_escape :: boolean()
        }

  @type text_group :: {
          :text_group,
          cursor :: cursor(),
          tag_name :: charlist()
        }

  @type token() ::
          tag_start()
          | tag_end()
          | tag_text()
          | tag_output()
          | text_group()
          | tag_comment()

  @type leaf() :: {
          token :: token(),
          children :: [leaf()]
        }

  @doc """
  Removes tailing and leading whitespace nodes from the given AST.
  """
  @spec drop_whitespace([leaf()]) :: [leaf()]
  def drop_whitespace(tree) do
    tree
    |> drop_leading_whitespace_and_reverse()
    |> drop_leading_whitespace_and_reverse()
  end

  defp drop_leading_whitespace_and_reverse(leaf, acc \\ [])

  defp drop_leading_whitespace_and_reverse([{token = {:text_group, _, _}, nested} | tail], []) do
    filtered_text =
      Enum.filter(nested, fn
        {{:tag_text, _, _, _, is_blank}, []} -> !is_blank
        _ -> true
      end)

    acc =
      case filtered_text do
        [] -> []
        _ -> [{token, filtered_text}]
      end

    drop_leading_whitespace_and_reverse(tail, acc)
  end

  defp drop_leading_whitespace_and_reverse([head | tail], acc) do
    drop_leading_whitespace_and_reverse(tail, [head | acc])
  end

  defp drop_leading_whitespace_and_reverse([], acc) do
    acc
  end
end
