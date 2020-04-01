defmodule ExTweet.Parser.TweetTest do
  use ExUnit.Case, async: true

  alias ExTweet.Parser.Tweet

  @json_init "test/resources/bbcnews_2019-01-01_to_02_init.json"
  def raw_tweets_fixture() do
    File.read!(@json_init)
    |> Jason.decode!()
    |> Map.fetch!("items_html")
    |> Tweet.split_stream_into_tweets()
  end

  describe "Tweet" do
    test "username is extracted" do
      # Given
      tweet_html = raw_tweets_fixture() |> hd

      # When
      tweet = Tweet.parse_tweet(tweet_html)

      # Then
      assert Map.get(tweet, :username) == "BBCNews"
    end

    test "user_id is extracted" do
      # Given
      tweet_html = raw_tweets_fixture() |> hd
      expected = 612_473

      # When
      tweet = Tweet.parse_tweet(tweet_html)

      # Then
      assert Map.get(tweet, :user_id) == expected
    end

    test "tweet_id is extracted" do
      # Given
      tweet_html = raw_tweets_fixture() |> hd
      expected = 1_080_238_541_031_047_174

      # When
      tweet = Tweet.parse_tweet(tweet_html)

      # Then
      assert Map.get(tweet, :id) == expected
    end

    test "creation_datetime is extracted" do
      # Given
      tweet_html = raw_tweets_fixture() |> hd

      # When
      tweet = Tweet.parse_tweet(tweet_html)

      # Then
      assert Map.get(tweet, :datetime) == ~U[2019-01-01 23:05:12Z]
    end

    test "text is extracted" do
      # Given
      tweet_html = raw_tweets_fixture() |> hd
      expected_text = "Newspaper headlines: 'Panic on the platform'"

      # When
      tweet = Tweet.parse_tweet(tweet_html)

      # Then
      assert Map.get(tweet, :text) == expected_text
    end

    test "links are extracted" do
      # Given
      tweet_html = raw_tweets_fixture() |> hd
      expected_url = "https://bbc.in/2F4kxjj"

      # When
      tweet = Tweet.parse_tweet(tweet_html)
      links = Map.get(tweet, :links, [])

      # Then
      assert expected_url in links
      assert links |> length() == 1
    end

    test "permalink is extracted" do
      # Given
      tweet_html = raw_tweets_fixture() |> hd

      # When
      tweet = Tweet.parse_tweet(tweet_html)

      # Then
      assert Map.get(tweet, :url) == "https://twitter.com/BBCNews/status/1080238541031047174"
    end
  end

  describe "Tweet text" do
    @tweet_with_an_at_user "test/resources/tweet_with_an_at_user.bin"
    @tweet_with_image_no_text "test/resources/tweet_with_just_an_image.bin"
    @tweet_with_many_ats_in_text "test/resources/tweet_with_many_ats_in_text.bin"
    @tweet_with_many_emojis "test/resources/tweet_with_many_emojis.bin"
    @tweet_with_urls_and_hashtags "test/resources/tweet_with_urls_and_hashtags.bin"
    @tweet_with_strong_tags_in_text "test/resources/tweet_with_strong_tags_in_text.bin"

    def deserialize_floki_html_tree(filename) do
      # Returns a Floki HTML tree, deserialized from a binary file
      # Binary created with :erlang.term_to_binary/1
      {:ok, binary} = File.read(filename)
      :erlang.binary_to_term(binary)
    end

    test "with strong tags" do
      ## Tweet -> https://twitter.com/seacoastrunner/status/947692897654202368

      # Given
      parsed_html = deserialize_floki_html_tree(@tweet_with_strong_tags_in_text)
      expected_text_substring = "teary-eyed watching clips of"
      unexpected_text_substring = "watchingclips"

      # When
      expected_text =
        "I still get teary-eyed watching clips of @rogerfederer winning " <>
          "Wimbledon in 2017. His kids were so funny and sweet!"

      tweet = Tweet.parse_tweet(parsed_html)

      # Then
      assert tweet.text =~ expected_text_substring
      refute tweet.text =~ unexpected_text_substring
      assert tweet.text == expected_text
    end

    test "with @User is in-lined with text" do
      ## Tweet -> https://twitter.com/charltonbrooker/status/1229553265551069184
      # Given
      parsed_html = deserialize_floki_html_tree(@tweet_with_an_at_user)
      expected_at_user = "@UpstartCrowPlay"
      # When
      expected_text =
        "Just had a genuine laugh-out-loud night out " <>
          "seeing @UpstartCrowPlay at the theatre. " <>
          "And I usually *hate* plays."

      tweet = Tweet.parse_tweet(parsed_html)

      # Then
      assert tweet.text =~ expected_at_user
      assert tweet.text == expected_text
    end

    test "with many @users in lined in text and non-inlined URL" do
      ## Tweet -> https://twitter.com/KermodeMovie/status/1228377364201078784
      # Given
      parsed_html = deserialize_floki_html_tree(@tweet_with_many_ats_in_text)

      expected_url =
        "https://www.bbc.co.uk/programmes/articles/2vrDWcYw54hg3M6pQnk1BLv/the-witterlist-14th-february-2020"

      expected_at_users = [
        "@1stlove_movie",
        "@KermodeMovie",
        "@SonicMovie",
        "@emmamovie",
        "@simonmayo"
      ]

      expected_text =
        "It's Valentine's Day, the perfect time to see Takashi Miike's " <>
          "ultra-violent romance, @1stlove_movie. @KermodeMovie reviewed it " <>
          "on today's show, along with @SonicMovie, Spycies & @emmamovie - " <>
          "for which star Anya Taylor-Joy talked to @simonmayo."

      # When
      tweet = Tweet.parse_tweet(parsed_html)

      # Then
      assert Enum.all?(expected_at_users, fn expected_at_user ->
               tweet.text =~ expected_at_user
             end) == true

      assert tweet.text == expected_text
      refute tweet.text =~ expected_url
      assert expected_url in tweet.links
    end

    test "with just an image has placeholder" do
      ## Tweet -> https://twitter.com/KermodeMovie/status/1229716926974308352
      # Given
      parsed_html = deserialize_floki_html_tree(@tweet_with_image_no_text)
      expected_text = "#HistoricTwitter:no_text"

      # When
      tweet = Tweet.parse_tweet(parsed_html)

      # Then
      assert tweet.text == expected_text
    end

    test "with many emojis in lined in text" do
      ## Tweet -> https://twitter.com/KermodeMovie/status/1229722716556742657
      # Given
      parsed_html = deserialize_floki_html_tree(@tweet_with_many_emojis)

      expected_text =
        "📀Comments welcome for DVD OF THE WEEK 👇Lots of rereleases to choose from " <>
          "📩Comment below or DMs us 📽Brothers Till We Die 🐲Dragons Forever " <>
          "💔Holiday 👰Endless Night 🏃‍♀️Freaks 🐝Honeyland 👾Relaxer 🇲🇽Roma " <>
          "💃🏻Scandal 🚘The Fast Lady 📝Full list in comments"

      # When
      tweet = Tweet.parse_tweet(parsed_html)

      # Then
      assert tweet.text == expected_text
    end

    test "with in-lined links and hashtags text" do
      ## Tweet -> https://twitter.com/tw_lgiordani/status/1229417387386167301
      # Given
      parsed_html = deserialize_floki_html_tree(@tweet_with_urls_and_hashtags)
      expected_url = "https://www.thedigitalcatonline.com/blog/2020/02/16/dissecting-a-web-stack/"

      expected_text =
        "An attempt to describe what's in a (Python) web stack " <>
          "layer by layer. Starting from sockets up to " <>
          "the web server. Hope this helps! " <>
          "#Python #wsgi #http #https #aws #apache #flask #django"

      # When
      tweet = Tweet.parse_tweet(parsed_html)

      # Then
      assert tweet.text == expected_text
      refute tweet.text =~ expected_url
      assert expected_url in tweet.links
    end
  end
end
