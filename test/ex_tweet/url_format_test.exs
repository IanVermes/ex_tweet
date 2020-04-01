defmodule ExTweet.UrlFormatTest do
  use ExUnit.Case, async: true

  alias ExTweet.Query
  alias ExTweet.UrlFormat

  @base_url "https://twitter.com/i/search/timeline?f=tweets&vertical=news&"
  @query_constant "%20-filter%3Areplies"
  @query_params "&src=typd&&include_available_features=1&include_entities=1"
  @max_position "&max_position="
  @end_url "&reset_error_state=false"
  @example_cursor "thGAVUV0VFVBaAwL7dyIeQ_R0WjIC87dnO4_0dEjUAFQAlAFUAFQAA"

  @date_from ~D[2019-01-01]
  @date_to ~D[2019-01-02]

  def concat_url_fixture(query, cursor \\ nil) do
    data_query_subcomponent = "%20since%3A#{@date_from}%20until%3A#{@date_to}"

    if is_nil(cursor) do
      @base_url <>
        query <>
        data_query_subcomponent <> @query_constant <> @query_params <> @max_position <> @end_url
    else
      @base_url <>
        query <>
        data_query_subcomponent <>
        @query_constant <> @query_params <> "#{@max_position}#{@example_cursor}" <> @end_url
    end
  end

  def construct_query_with_specific_dates(attrs = %{}) do
    Query.new(@date_from, @date_to, attrs)
  end

  describe "json_url/2 with :username query" do
    test "without cursor" do
      # Given
      query =
        %{username: "BBCNews"}
        |> construct_query_with_specific_dates()

      expected_substring = "q=from%3Abbcnews"
      expected_url = concat_url_fixture(expected_substring)

      # When
      actual_url = UrlFormat.json_url(query)

      # Then
      assert actual_url =~ expected_substring
      assert expected_url == actual_url
    end

    test "and cursor" do
      # Given
      query =
        %{username: "BBCNews"}
        |> construct_query_with_specific_dates()

      cursor = @example_cursor
      expected_substring = "q=from%3Abbcnews"
      expected_url = concat_url_fixture(expected_substring, @example_cursor)

      # When
      actual_url = UrlFormat.json_url(query, cursor)

      # Then
      assert actual_url =~ expected_substring
      assert actual_url =~ cursor
      assert expected_url == actual_url
    end
  end

  describe "json_url/2 with :words_all query" do
    test "with single word" do
      ## E.g. Search: `tennis since:$DATE until:$DATE`

      # Given
      query =
        %{words_all: ["tennis"]}
        |> construct_query_with_specific_dates()

      expected_substring = "q=tennis"
      expected_url = concat_url_fixture(expected_substring)

      # When
      actual_url = UrlFormat.json_url(query)

      # Then
      assert actual_url =~ expected_substring
      assert expected_url == actual_url
    end

    test "with multiple words" do
      ## E.g. Search: `mixed doubles final since:$DATE until:$DATE`
      query =
        %{words_all: ["mixed", "doubles", "final"]}
        |> construct_query_with_specific_dates()

      expected_substring = "q=mixed%20doubles%20final"
      expected_url = concat_url_fixture(expected_substring)

      # When
      actual_url = UrlFormat.json_url(query)

      # Then
      assert actual_url =~ expected_substring
      assert expected_url == actual_url
    end

    test "with a single phrase" do
      # E.g. Search: `"mixed doubles final" since:$DATE until:$DATE`

      # Given
      query =
        %{words_all: ["mixed doubles final"]}
        |> construct_query_with_specific_dates()

      expected_substring = "q=%22mixed%20doubles%20final%22"
      expected_url = concat_url_fixture(expected_substring)

      # When
      actual_url = UrlFormat.json_url(query)

      # Then
      assert actual_url =~ expected_substring
      assert expected_url == actual_url
    end

    test "with a multiple phrases" do
      # E.g. Search: `"mixed doubles final" "henman hill" since:$DATE until:$DATE`

      # Given
      query =
        %{words_all: ["mixed doubles final", "henman hill"]}
        |> construct_query_with_specific_dates()

      expected_substring = "q=%22mixed%20doubles%20final%22%20%22henman%20hill%22"
      expected_url = concat_url_fixture(expected_substring)

      # When
      actual_url = UrlFormat.json_url(query)

      # Then
      assert actual_url =~ expected_substring
      assert expected_url == actual_url
    end
  end

  describe "json_url/2 with :words_any query" do
    test "with two words" do
      ## E.g. Search: `(germany OR france) since:$DATE until:$DATE`

      # Given
      query =
        %{words_any: [["germany", "france"]]}
        |> construct_query_with_specific_dates()

      expected_substring = "q=(germany%20OR%20france)"
      expected_url = concat_url_fixture(expected_substring)

      # When
      actual_url = UrlFormat.json_url(query)

      # Then
      assert actual_url =~ expected_substring
      assert expected_url == actual_url
    end

    test "with two phrases" do
      ## E.g. Search: `("german player" OR "french player") since:$DATE until:$DATE`
      # The `%22` == `"` in the substring

      # Given
      query =
        %{words_any: [["german player", "french player"]]}
        |> construct_query_with_specific_dates()

      expected_substring = "q=(%22german%20player%22%20OR%20%22french%20player%22)"
      expected_url = concat_url_fixture(expected_substring)

      # When
      actual_url = UrlFormat.json_url(query)

      # Then
      assert actual_url =~ expected_substring
      assert expected_url == actual_url
    end

    test "with two groups of two words" do
      ## E.g. Search: `(pimms OR strawberries) (singles OR doubles) since:$DATE until:$DATE`

      # Given
      query =
        %{words_any: [["singles", "doubles"], ["pimms", "strawberries"]]}
        |> construct_query_with_specific_dates()

      expected_substring = "q=(pimms%20OR%20strawberries)%20(singles%20OR%20doubles)"

      expected_url = concat_url_fixture(expected_substring)

      # When
      actual_url = UrlFormat.json_url(query)

      # Then
      assert actual_url =~ expected_substring
      assert expected_url == actual_url
    end

    test "with two groups of words & phrases" do
      ## E.g. Search: `(mens OR gentlemens) ("singles game" OR "doubles game") since:$DATE until:$DATE`
      # The `%22` == `"` in the substring

      # Given
      query =
        %{words_any: [["singles game", "doubles game"], ["mens", "gentlemens"]]}
        |> construct_query_with_specific_dates()

      expected_substring =
        "q=(mens%20OR%20gentlemens)%20(%22singles%20game%22%20OR%20%22doubles%20game%22)"

      expected_url = concat_url_fixture(expected_substring)

      # When
      actual_url = UrlFormat.json_url(query)

      # Then
      assert actual_url =~ expected_substring
      assert expected_url == actual_url
    end
  end

  describe "json_url/2 with :words_exclude query" do
    @words_all_search_term ["tennis", "match"]
    test "with a single word + :words_all query" do
      ## E.g. Search: `tennis match -badminton since:$DATE until:$DATE`

      # Given
      query =
        %{
          words_all: @words_all_search_term,
          words_exclude: ["badminton"]
        }
        |> construct_query_with_specific_dates()

      expected_substring = "q=tennis%20match%20-badminton"
      expected_url = concat_url_fixture(expected_substring)

      # When
      actual_url = UrlFormat.json_url(query)

      # Then
      assert actual_url =~ expected_substring
      assert expected_url == actual_url
    end

    test "with a multiple words + :words_all query" do
      ## E.g. Search: `tennis match -squash -badminton since:$DATE until:$DATE`

      # Given
      query =
        %{
          words_all: @words_all_search_term,
          words_exclude: ["badminton", "squash"]
        }
        |> construct_query_with_specific_dates()

      expected_substring = "q=tennis%20match%20-badminton%20-squash"
      expected_url = concat_url_fixture(expected_substring)

      # When
      actual_url = UrlFormat.json_url(query)

      # Then
      assert actual_url =~ expected_substring
      assert expected_url == actual_url
    end

    test "with a single phrase + :words_all query" do
      ## E.g. Search: `tennis match -"contested point" since:$DATE until:$DATE`

      # Given
      query =
        %{
          words_all: @words_all_search_term,
          words_exclude: ["contested point"]
        }
        |> construct_query_with_specific_dates()

      expected_substring = "q=tennis%20match%20-%22contested%20point%22"
      expected_url = concat_url_fixture(expected_substring)

      # When
      actual_url = UrlFormat.json_url(query)

      # Then
      assert actual_url =~ expected_substring
      assert expected_url == actual_url
    end

    test "with a multiple phrase + :words_all query" do
      ## E.g. Search: `tennis match -"contested point" -"umpire ruling" since:$DATE until:$DATE`

      # Given
      query =
        %{
          words_all: @words_all_search_term,
          words_exclude: ["contested point", "umpire ruling"]
        }
        |> construct_query_with_specific_dates()

      expected_substring = "q=tennis%20match%20-%22contested%20point%22%20-%22umpire%20ruling%22"
      expected_url = concat_url_fixture(expected_substring)

      # When
      actual_url = UrlFormat.json_url(query)

      # Then
      assert actual_url =~ expected_substring
      assert expected_url == actual_url
    end
  end
end
