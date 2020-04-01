defmodule ExTweetTest do
  use ExUnit.Case

  describe "API" do
    test "user_tweets/3" do
      # Given
      handle = "BBCNews"
      date_from = ~D[2019-01-01]
      date_to = ~D[2019-01-02]
      expected_count = 35

      # When
      assert {:ok, tweets} = ExTweet.user_tweets(date_from, date_to, handle)

      # Then
      assert length(tweets) == expected_count
    end

    test "advanced_search/3" do
      ## Equivalent to the search `wimbledon wheelchair doubles (womens OR mixed) -"mens" since:2016-07-08 until:2016-07-11 -filter:replies`
      ## in the Latest Tweets category (not Top Tweets)

      # Given
      query = %{
        words_all: ["wimbledon", "wheelchair", "doubles"],
        words_any: [["mixed", "womens"]],
        words_exclude: ["mens"]
      }

      date_from = ~D[2016-07-08]
      date_to = ~D[2016-07-11]
      expected_count = 36

      # When
      assert {:ok, tweets} = ExTweet.advanced_search(date_from, date_to, query)

      # Then
      assert length(tweets) == expected_count
    end
  end
end
