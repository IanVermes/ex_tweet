defmodule ExTweet.Filter do
  alias ExTweet.Query
  alias ExTweet.Parser.Tweet

  @type keyword_query() :: String.t() | Regex.t()
  # grouped_any_keywords is a list of lists
  @type grouped_any_keywords() :: [nonempty_list(keyword_query())]
  @name __MODULE__

  require Logger

  ## API

  @spec filter([Tweet.t()], Query.t()) :: [Tweet.t()]
  def filter(tweets, query) do
    all_keywords =
      case query.words_all do
        nil -> []
        words -> compile_keywords(words)
      end

    grouped_any_keywords =
      case query.words_any do
        [_ | _] = grouped_words ->
          Enum.map(grouped_words, fn words -> compile_keywords(words) end)

        [] ->
          []

        nil ->
          []
      end

    # Step 1: filter tweets against membership of all keywords
    filtered_tweets = Enum.filter(tweets, &has_all_keywords?(&1, all_keywords))

    # Step 2: filter remaining tweets against membership of any keywords from each group
    filter_any_keyword_groups(grouped_any_keywords, filtered_tweets)
  end

  ## Private
  @spec filter_any_keyword_groups(grouped_any_keywords(), [Tweet.t()]) :: [Tweet.t()]
  defp filter_any_keyword_groups(grouped_any_keywords, tweets)

  defp filter_any_keyword_groups([any_keywords | other_keyword_groups], tweets) do
    filtered_tweets = Enum.filter(tweets, &has_any_keywords?(&1, any_keywords))
    filter_any_keyword_groups(other_keyword_groups, filtered_tweets)
  end

  defp filter_any_keyword_groups([], tweets) do
    tweets
  end

  @spec has_all_keywords?(Tweet.t() | String.t(), [keyword_query()]) :: boolean()
  defp has_all_keywords?(%Tweet{text: text}, keywords) do
    has_all_keywords?(text, keywords)
  end

  defp has_all_keywords?(string, [_ | _] = keywords) do
    outcome = Enum.all?(keywords, fn kw -> has_keyword?(string, kw) end)

    if outcome do
      outcome
    else
      Logger.debug("#{@name} all dropping text=\"#{string}\" keywords=#{inspect(keywords)}")
      outcome
    end
  end

  defp has_all_keywords?(_string, []) do
    true
  end

  @spec has_any_keywords?(Tweet.t() | String.t(), [keyword_query()]) :: boolean()
  defp has_any_keywords?(%Tweet{text: text}, keywords) do
    has_any_keywords?(text, keywords)
  end

  defp has_any_keywords?(string, [_ | _] = keywords) do
    outcome = Enum.any?(keywords, fn kw -> has_keyword?(string, kw) end)

    if outcome do
      outcome
    else
      Logger.debug("#{@name} any dropping text=\"#{string}\" keywords=#{inspect(keywords)}")
      outcome
    end
  end

  defp has_any_keywords?(_string, []) do
    true
  end

  @spec has_keyword?(String.t(), keyword_query()) :: boolean()
  defp has_keyword?(string, %Regex{} = regex) do
    do_keyword_comparison(string, regex)
  end

  @spec compile_keywords([String.t()]) :: [Regex.t()]
  defp compile_keywords(keywords) do
    Enum.map(keywords, &compile_keyword/1)
  end

  @spec compile_keyword(String.t()) :: Regex.t()
  defp compile_keyword(keyword) do
    {:ok, regex} = Regex.compile(keyword, [:caseless, :unicode])
    regex
  end

  defp do_keyword_comparison(string, regex), do: string =~ regex
end
