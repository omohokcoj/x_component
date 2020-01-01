defmodule X.Ast do
  alias List.Chars

  @type cursor() :: {
          column :: integer(),
          row :: integer()
        }

  @type tag_attr() :: {
          :tag_attr,
          cursor(),
          name :: Chars.t(),
          value :: Chars.t(),
          is_dynamic :: boolean()
        }

  @type tag_condition() :: {
          condition :: :if | :else | :elseif | :unless,
          cursor :: cursor(),
          value :: Chars.t()
        }

  @type tag_iterator() :: {
          iterator :: :for,
          cursor :: cursor(),
          value :: Chars.t()
        }

  @type tag_comment() :: {
          :tag_comment,
          cursor :: cursor(),
          value :: Chars.t()
        }

  @type tag_start() :: {
          :tag_start,
          cursor :: cursor(),
          name :: Chars.t(),
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
          name :: Chars.t()
        }

  @type tag_text() :: {
          :tag_text,
          cursor :: cursor(),
          value :: Chars.t(),
          is_leading_whitespace :: boolean(),
          is_blank :: boolean()
        }

  @type tag_output() :: {
          :tag_output,
          cursor :: cursor(),
          value :: Chars.t(),
          is_html_escape :: boolean()
        }

  @type text_group :: {
          :text_group,
          cursor :: cursor(),
          tag_name :: Chars.t()
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
end
