defmodule ExTweet.Parser do
  defstruct has_tweets?: nil, has_items?: nil, tweets: [], cursor: nil

  alias ExTweet.Parser.Tweet

  @type t :: %__MODULE__{
          has_tweets?: boolean(),
          has_items?: boolean(),
          tweets: [Tweet.t()],
          cursor: binary | atom
        }

  ## API

  @spec parse(String.t()) :: __MODULE__.t()
  def parse(response_body) do
    {:ok, json} =
      Jason.decode!(response_body)
      |> check_schema()

    %__MODULE__{}
    |> evaluate_cursor!(json)
    |> evaluate_boolean_flags!(json)
    |> maybe_parse_tweets!(json)
  end

  ## Private

  defp check_schema(%{"min_position" => _, "has_more_items" => _, "items_html" => _} = json) do
    {:ok, json}
  end

  defp check_schema(%{}) do
    {:error, :unknown_json_schema}
  end

  defp evaluate_cursor!(%__MODULE___{} = acc, json) do
    cursor = Map.fetch!(json, "min_position")
    Map.replace!(acc, :cursor, cursor)
  end

  defp evaluate_boolean_flags!(%__MODULE___{} = acc, json) do
    # The json has a boolean flag, relating to the items on the NEXT page. We
    # care about this flag as it determines whether we need another request.
    more_items_flag = Map.fetch!(json, "has_more_items")
    acc = Map.replace!(acc, :has_items?, more_items_flag)

    # The json may not contain any tweets and is another signal as to whether
    # more requests are necessary. E.g. perhaps the next page has tweets, has
    # incomplete tweets withheld by the Twitter Guidelines
    tweets_flag =
      json
      |> Map.fetch!("items_html")
      |> raw_tweet_html_contains_tweets?()

    Map.replace!(acc, :has_tweets?, tweets_flag)
  end

  defp raw_tweet_html_contains_tweets?(raw_html) do
    # JSON will carry HTML as a plain text string. The HTML encodes the 1 to 20
    # Tweets that populate the bottom of the page when scrolling in a browser.
    # When the tweet limit has been reached, rather than HTML, the requests has
    # a response of whitespace (e.g. a a dozen line breaks).
    String.length(String.trim(raw_html)) > 0
  end

  defp maybe_parse_tweets!(%__MODULE___{has_tweets?: true} = acc, json) do
    tweets =
      json
      |> Map.fetch!("items_html")
      |> Tweet.parse_tweet_stream()

    Map.replace!(acc, :tweets, tweets)
  end

  defp maybe_parse_tweets!(%__MODULE___{has_tweets?: false} = acc, _json) do
    Map.replace!(acc, :tweets, [])
  end
end
