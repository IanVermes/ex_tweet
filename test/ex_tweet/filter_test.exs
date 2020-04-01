defmodule ExTweet.FilterTest do
  use ExUnit.Case, async: true

  alias ExTweet.{Parser, Filter, Query}
  alias ExTweet.Parser.Tweet

  def parse_tweets_from_response_body(filename) do
    body = File.read!(filename)

    result = Parser.parse(body)
    result.tweets
  end

  def get_tweet_by_id(tweets, id) do
    case Enum.filter(tweets, fn tweet -> tweet.id == id end) do
      [tweet] -> tweet
      [] -> nil
    end
  end

  describe "filter/2" do
    @json_init "test/resources/simplesearch_wimbledon_2018-01-01_to_02.json"

    test "scraped tweets filtered by query: all words" do
      # Precondition
      before_tweets = parse_tweets_from_response_body(@json_init)
      ## ID of a tweet where neither `tennis` nor `player` are both present
      tweet_without_keywords = get_tweet_by_id(before_tweets, 947_853_510_040_731_648)
      tweet_text = String.downcase(tweet_without_keywords.text)
      refute tweet_text =~ "game"
      refute tweet_text =~ "tennis"
      assert tweet_text =~ "wimbledon"

      # Given
      before_tweets_count = length(before_tweets)
      query = Query.new(~D[2018-01-01], ~D[2018-01-02], %{words_all: ["tennis", "player"]})

      # When
      after_tweets = Filter.filter(before_tweets, query)
      after_tweets_count = length(after_tweets)

      # Then
      assert before_tweets_count == 20
      assert after_tweets_count != 0
      assert before_tweets_count > after_tweets_count
      refute tweet_without_keywords in after_tweets
    end

    test "scraped tweets filtered by query: any words" do
      # Precondition
      tweet_without_keywords = %Tweet{text: "Training young squash players!"}
      before_tweets = [tweet_without_keywords]

      # Given
      before_tweets_count = length(before_tweets)
      query = Query.new(~D[2020-02-17], ~D[2020-02-19], %{words_any: [["tennis", "wimbledon"]]})

      # When
      after_tweets = Filter.filter(before_tweets, query)
      after_tweets_count = length(after_tweets)

      # Then
      assert before_tweets_count == 1
      assert after_tweets_count == 0
      refute tweet_without_keywords in after_tweets
    end

    test "scraped tweets filtered by query: multiple any words" do
      # Precondition
      tweet_1_without_keywords = %Tweet{text: "Training young squash players!"}
      tweet_2_without_keywords = %Tweet{text: "Yawning at old tennis players!"}
      before_tweets = [tweet_1_without_keywords, tweet_2_without_keywords]

      # Given
      before_tweets_count = length(before_tweets)

      query =
        Query.new(~D[2020-02-17], ~D[2020-02-19], %{
          words_any: [["tennis", "wimbledon"], ["watching", "watch"]]
        })

      # When
      after_tweets = Filter.filter(before_tweets, query)
      after_tweets_count = length(after_tweets)

      # Then
      assert before_tweets_count == 2
      assert before_tweets_count > after_tweets_count
      refute tweet_1_without_keywords in after_tweets
      refute tweet_2_without_keywords in after_tweets
    end

    test "scraped tweets filtered by query: any + all words" do
      # Precondition
      tweet_without_keywords = %Tweet{text: "Training young hockey players!"}
      before_tweets = [tweet_without_keywords]

      # Given
      before_tweets_count = length(before_tweets)

      query =
        Query.new(~D[2020-02-17], ~D[2020-02-19], %{
          words_any: [["tennis", "wimbledon"]],
          words_all: ["players"]
        })

      # When
      after_tweets = Filter.filter(before_tweets, query)
      after_tweets_count = length(after_tweets)

      # Then
      assert before_tweets_count == 1
      assert after_tweets_count == 0
      refute tweet_without_keywords in after_tweets
    end

    test "scraped tweets filtered by query: exact phrase" do
      # Precondition
      tweet_without_keywords = %Tweet{text: "Be a match maker! Stream live tennis!"}
      before_tweets = [tweet_without_keywords]

      # Given
      before_tweets_count = length(before_tweets)
      query = Query.new(~D[2020-02-17], ~D[2020-02-19], %{words_all: ["tennis match"]})

      # When
      after_tweets = Filter.filter(before_tweets, query)
      after_tweets_count = length(after_tweets)

      # Then
      assert before_tweets_count == 1
      assert after_tweets_count == 0
      refute tweet_without_keywords in after_tweets
    end
  end
end
