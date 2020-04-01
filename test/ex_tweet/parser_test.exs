defmodule ExTweet.ParserTest do
  use ExUnit.Case, async: true

  alias ExTweet.Parser

  describe "parse/1" do
    def load_json_as_response_body(filename) do
      File.read!(filename)
      |> Jason.decode!()
      |> Jason.encode!()
    end

    @json_init "test/resources/bbcnews_2019-01-01_to_02_init.json"
    @json_cursor "test/resources/bbcnews_2019-01-01_to_02_cursor.json"
    @json_end "test/resources/bbcnews_2019-01-01_to_02_end.json"

    test "with response body - init" do
      # Given
      body = load_json_as_response_body(@json_init)
      expected_cursor = "thGAVUV0VFVBaAwL7dyIeQ_R0WjIC87dnO4_0dEjUAFQAlAFUAFQAA"

      # When
      result = Parser.parse(body)

      # Then
      assert result.has_items? == true
      assert result.has_tweets? == true
      assert result.cursor == expected_cursor
      assert result.tweets |> length() == 20
    end

    test "with response body - has cursor" do
      # Given
      body = load_json_as_response_body(@json_cursor)
      expected_cursor = "thGAVUV0VFVBaEwL6ltafW_B0WjIC87dnO4_0dEjUAFQAlAFUAFQAA"

      # When
      result = Parser.parse(body)

      # Then
      assert result.has_items? == false
      assert result.has_tweets? == true
      assert result.cursor == expected_cursor
      assert result.tweets |> length() == 15
    end

    test "with response body - end" do
      # Given
      body = load_json_as_response_body(@json_end)
      expected_cursor = "thGAVUV0VFVBaEwL6ltafW_B0WjIC87dnO4_0dEjUAFQAlAFUAFQAA"

      # When
      result = Parser.parse(body)

      # Then
      assert result.has_items? == false
      assert result.has_tweets? == false
      assert result.cursor == expected_cursor
      assert result.tweets |> length() == 0
    end
  end
end
