defmodule ExTweet.UrlFormat do
  @json_twitter_base "https://twitter.com/i/search/timeline?f=tweets&vertical=news"
  @json_twitter_query_substring "-filter:replies"
  @json_twitter_constants_1 "&src=typd&&include_available_features=1&include_entities=1"
  @json_twitter_constants_2 "&reset_error_state=false"

  alias ExTweet.Query

  ## API
  @spec json_url(Query.t(), String.t() | nil) ::
          binary
  def json_url(query, cursor \\ nil)

  def json_url(%{} = query, nil) do
    json_url(query, "")
  end

  def json_url(%{} = query, cursor) do
    @json_twitter_base <>
      build_query_component(query) <>
      @json_twitter_constants_1 <>
      build_cursor_component(cursor) <>
      @json_twitter_constants_2
  end

  ## Private

  defp build_query_component(query) do
    query = clean_query(query)

    list_of_terms =
      []
      # Query terms are handled with `format_*`.
      # Inclusion of terms is ordered and optional.
      |> filter_out_replies()
      |> format_date_to(query)
      |> format_date_from(query)
      |> format_username(query)
      |> format_words_exclude(query)
      |> format_words_any(query)
      |> format_words_all(query)

    query_terms =
      list_of_terms
      |> Enum.join("%20")

    # |> URI.encode(&URI.char_unreserved?/1)

    "&q=#{query_terms}"
  end

  defp build_cursor_component(cursor) do
    cursor_term = URI.encode(cursor, &URI.char_unreserved?/1)

    "&max_position=#{cursor_term}"
  end

  defp clean_query(%Query{} = query), do: query |> Map.from_struct() |> clean_query()

  defp clean_query(%{} = query),
    do: Enum.filter(query, fn {_key, value} -> not is_nil(value) end) |> Map.new()

  defp format_words_all(acc, %{words_all: term}), do: [do_format_words_all(term) | acc]
  defp format_words_all(acc, _query), do: acc

  defp filter_out_replies(acc) do
    query_component =
      @json_twitter_query_substring
      |> URI.encode_www_form()

    [query_component | acc]
  end

  defp format_words_any(acc, %{words_any: [_ | _] = list_of_groups}) do
    # Collectable protocol is deprecated for non-empty lists when using the
    # `into:` in a comprehension. When collecting into a non-empty list,
    # consider concatenating the two lists with the ++ operator.
    formatted_any =
      for group_of_words <- Enum.reverse(list_of_groups), into: [] do
        do_format_words_any(group_of_words)
      end

    formatted_any ++ acc
  end

  defp format_words_any(acc, _query), do: acc

  defp format_words_exclude(acc, %{words_exclude: term}),
    do: [do_format_words_exclude(term) | acc]

  defp format_words_exclude(acc, _query), do: acc

  defp format_username(acc, %{username: username}) do
    username = String.downcase(username)
    [URI.encode_www_form("from:#{username}") | acc]
  end

  defp format_username(acc, _query), do: acc

  defp format_date_from(acc, %{date_from: date}), do: [URI.encode_www_form("since:#{date}") | acc]
  defp format_date_from(acc, _query), do: acc

  defp format_date_to(acc, %{date_to: date}), do: [URI.encode_www_form("until:#{date}") | acc]
  defp format_date_to(acc, _query), do: acc

  defp do_format_words_any(list_of_strings) do
    or_phrase =
      list_of_strings
      |> escape_phrases_not_words()
      |> Enum.intersperse("OR")
      |> Enum.join(" ")

    # Wrap in parenthesis, e.g `(france OR germany OR "united states")`
    or_phrase = "(#{or_phrase})"

    URI.encode(or_phrase)
  end

  defp do_format_words_exclude(list_of_strings) do
    # Each excluded word is pre-pended with a `-` and escaped e.g. `-"lawn tennis" -wimbledon`
    list_of_strings
    |> escape_phrases_not_words()
    |> Enum.map(fn term -> "-#{term}" end)
    |> Enum.join(" ")
    |> URI.encode()
  end

  defp do_format_words_all(list_of_strings) do
    # Exact phrases are wrapped in double quotes and escaped e.g. `"mixed doubles final"`
    list_of_strings
    |> escape_phrases_not_words()
    |> Enum.join(" ")
    |> URI.encode()
  end

  defp escape_phrases_not_words(words_and_phrases) do
    for term <- words_and_phrases do
      # Term can be a single word `hello` or a phrase `hello world`
      if term =~ " " do
        # is a phrase
        double_quote_escape(term)
      else
        # is a word
        term
      end
    end
  end

  defp double_quote_escape(phrase) do
    "\"" <> phrase <> "\""
  end
end
