defmodule ExTweet.Parser.Tweet do
  defstruct [:id, :datetime, :username, :user_id, :text, :url, :links]

  @multiple_space_regex Regex.compile!(~S(\s{1,}), [:caseless, :unicode])

  @type t :: %__MODULE__{
          id: integer(),
          user_id: integer(),
          datetime: DateTime.t(),
          username: String.t(),
          text: String.t(),
          url: String.t(),
          links: [String.t()]
        }

  ## API

  @spec parse_tweet_stream(String.t()) :: [__MODULE__.t()]
  def parse_tweet_stream(raw_html) do
    split_stream_into_tweets(raw_html)
    |> Enum.filter(&has_usernames?/1)
    |> Enum.map(&parse_tweet/1)
  end

  @spec parse_tweet(Floki.html_tree()) :: __MODULE__.t()
  def parse_tweet(tweet) do
    %__MODULE__{}
    |> extract_creation_datetime(tweet)
    |> extract_tweet_id(tweet)
    |> extract_user_id(tweet)
    |> extract_username(tweet)
    |> extract_text(tweet)
    |> extract_permalink(tweet)
  end

  def split_stream_into_tweets(raw_html) do
    {:ok, tweet_stream} = Floki.parse_fragment(raw_html)
    # Remove incomplete tweets withheld by Twitter Guidelines
    # Has selector: div.withheld-tweet
    tweet_stream =
      Floki.traverse_and_update(tweet_stream, fn
        {"div", [{"withheld-tweet", _} | _], _children} -> nil
        tag -> tag
      end)

    # Tweets
    Floki.find(tweet_stream, "div.js-stream-tweet")
  end

  ## Private

  defp extract_creation_datetime(map, tweet) do
    [timestamp] =
      tweet
      |> Floki.find("small.time span.js-short-timestamp")
      |> Floki.attribute("data-time")

    datetime =
      timestamp
      |> String.to_integer()
      |> DateTime.from_unix!()

    Map.put(map, :datetime, datetime)
  end

  defp extract_text(map, tweet) do
    {text, links} = process_text(tweet)

    text =
      if text == "" do
        "#HistoricTwitter:no_text"
      else
        text
      end

    map
    |> Map.put(:text, text)
    |> Map.put(:links, links)
  end

  defp extract_permalink(map, tweet) do
    [perma] = Floki.attribute(tweet, "data-permalink-path")
    url = "https://twitter.com" <> perma
    Map.put(map, :url, url)
  end

  defp extract_tweet_id(map, tweet) do
    [id] = Floki.attribute(tweet, "data-tweet-id")
    Map.put(map, :id, String.to_integer(id))
  end

  defp extract_user_id(map, tweet) do
    # Zeroth IDs is the author of the tweet, 1 --> N IDs correspond
    # to the recipients, if any.
    [author_id | _recipient_ids] =
      tweet
      |> Floki.find("a.js-user-profile-link")
      |> Floki.attribute("data-user-id")

    Map.put(map, :user_id, String.to_integer(author_id))
  end

  defp has_usernames?(tweet) do
    # Sometimes, in rare cases a Twitter search will return a tweet with no
    # usernames and hence not be valid.
    usernames(tweet) |> length() > 0
  end

  defp extract_username(map, tweet) do
    # Zeroth username is the author of the tweet, 1 --> N usernames correspond
    # to the recipients, if any.
    [author | _recipients] = usernames(tweet)
    Map.put(map, :username, author)
  end

  defp usernames(tweet) do
    tweet
    |> Floki.find("span.username.u-dir b")
    |> Floki.text(sep: " ")
    |> String.split()
  end

  def process_text(raw_tweet_html) do
    [{"p", _attrs, mixed_text}] = Floki.find(raw_tweet_html, "p.js-tweet-text")

    normalized_text =
      for element <- mixed_text do
        # Pack text into `<packed>` tags, as Floki.traverse_and_update can only
        # process Floki.tag types and not text between tags. By treating the text
        # like this, we can accurately track the last tag in the
        # Floki.traverse_and_update accumulator.
        if is_binary(element) do
          {"packed", [], [element]}
        else
          element
        end
      end

    acc = %{last_tag: :init, links: []}

    {processed_mixed_text, acc} =
      Floki.traverse_and_update(normalized_text, acc, fn
        {"packed", _, [text]} = packed_tag, acc ->
          {text, handle_process_text_accumulator(acc, packed_tag)}

        {"a", _, _} = link_tag, acc ->
          case process_link_tag(link_tag) do
            {text, :no_url} ->
              {text, handle_process_text_accumulator(acc, link_tag)}

            {text, url} ->
              {text, handle_process_text_accumulator(acc, link_tag, url)}
          end

        {"img", _, _} = img_tag, acc ->
          text = process_img_tag(img_tag)
          {text, handle_process_text_accumulator(acc, img_tag)}

        {"strong", _, _} = strong_tag, acc ->
          text = process_strong_tag(strong_tag, acc.last_tag)
          {text, handle_process_text_accumulator(acc, strong_tag)}

        tag, acc ->
          {tag, handle_process_text_accumulator(acc, tag)}
      end)

    cleaned_text =
      processed_mixed_text
      |> Floki.text(sep: "")
      |> clean_text_whitespace()

    {cleaned_text, acc.links}
  end

  defp handle_process_text_accumulator(acc, tag, url \\ nil)

  defp handle_process_text_accumulator(acc, tag, url) do
    tag_name =
      case tag do
        {tag_name, _, _} -> tag_name
        _ -> :text
      end

    acc = %{acc | last_tag: tag_name}

    if is_nil(url) do
      acc
    else
      %{acc | links: [url | acc.links]}
    end
  end

  defp clean_text_whitespace(text) do
    text
    |> String.replace("\n", " ")
    |> String.trim(" ")
    |> String.replace(@multiple_space_regex, " ")
  end

  defp process_img_tag({"img", attrs, _children}) do
    attrs = Map.new(attrs)
    classes = attribute_to_mapset(attrs, "class")

    cond do
      "Emoji" in classes ->
        case Map.get(attrs, "alt", :not_emoji) do
          :not_emoji ->
            title = Map.get(attrs, "title", "#HistoricTwitter:unknown_emoji")
            " Emoji[#{title}]"

          emoji ->
            " #{emoji}"
        end

      true ->
        nil
    end
  end

  defp process_strong_tag({"strong", _attrs, children}, last_tag) do
    text = Floki.text(children)

    if last_tag == "strong" do
      " " <> text
    else
      text
    end
  end

  defp process_link_tag({"a", attrs, children}) do
    attrs = Map.new(attrs)
    classes = attribute_to_mapset(attrs, "class")

    cond do
      "twitter-hashtag" in classes ->
        # format an @user (incase it has a strong tag)
        text = format_twitter_idiom(:hashtag, children)
        {text, :no_url}

      "twitter-atreply" in classes ->
        # format an @user (incase it has a strong tag)
        text = format_twitter_idiom(:at_user, children)
        {text, :no_url}

      "twitter-timeline-link" in classes ->
        case Map.get(attrs, "data-expanded-url", :no_url) do
          :no_url ->
            {nil, :no_url}

          url ->
            url = URI.parse(url) |> URI.to_string()
            {nil, url}
        end

      true ->
        {nil, :no_url}
    end
  end

  defp attribute_to_mapset(%{} = attrs, attribute_key) do
    attrs
    |> Map.get(attribute_key, "")
    |> String.split()
    |> MapSet.new()
  end

  defp format_twitter_idiom(:hashtag, children), do: do_format_twitter_idiom("#", children)
  defp format_twitter_idiom(:at_user, children), do: do_format_twitter_idiom("@", children)

  defp do_format_twitter_idiom(symbol, children) do
    text =
      Floki.text(children)
      |> String.trim_leading(symbol)
      |> String.trim_leading(" ")

    " #{symbol}" <> text
  end
end
