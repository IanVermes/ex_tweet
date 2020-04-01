defmodule ExTweet do
  @moduledoc """
  Public interface of ExTweet
  """

  alias ExTweet.{Scraper, Proxies}
  alias ExTweet.Parser.Tweet
  alias ExTweet.Query

  defguard is_proxy(value)
           when value in [:no_proxy, :random_proxy] or
                  (is_binary(elem(value, 0)) and is_binary(elem(value, 1)))

  @doc """
  Scrape the tweets of a single user over a continuous range of dates.

    ## Example

      iex> user_tweets(~D[2020-01-10], ~D[2020-01-15], "BBCNews")
      {:ok, [%ExTweet.Parser.Tweet{}, ...]}

  Scraping with a proxy is optional.
  - :no_proxy     --> no proxy will be used
  - :random_proxy --> a random proxy will be selected from https://free-proxy-list.net/
  - user specified proxy `{Host, Port}` tuple

  Regarding the date range
  - date_from is inclusive
  - date_to is exclusive
  """
  @spec user_tweets(
          Date.t(),
          Date.t(),
          binary,
          :no_proxy | :random_proxy | Proxies.proxy()
        ) ::
          {:ok, [Tweet.t()]} | {:error, atom()}
  def user_tweets(date_from, date_to, username, proxy \\ :no_proxy)

  def user_tweets(date_from, date_to, username, proxy) when is_proxy(proxy) do
    query = Query.new(date_from, date_to, %{username: username})
    Scraper.scrape(query, proxy)
  end

  @doc """
  Scrape a search phrase over a continuous range of dates.

    ## Example

      iex> ExTweet.simple_search(~D[2018-06-01], ~D[2018-06-02], ["climate crisis"])
      {:ok, [%ExTweet.Parser.Tweet{}, ...]}

  Scraping with a proxy is optional.
  - :no_proxy     --> no proxy will be used
  - :random_proxy --> a random proxy will be selected from https://free-proxy-list.net/
  - user specified proxy `{Host, Port}` tuple

  Regarding the date range
  - date_from is inclusive
  - date_to is exclusive
  """
  @spec simple_search(
          Date.t(),
          Date.t(),
          [binary],
          :no_proxy | :random_proxy | Proxies.proxy()
        ) ::
          {:ok, [Tweet.t()]} | {:error, atom()}

  def simple_search(date_from, date_to, search_term, proxy \\ :no_proxy)

  def simple_search(date_from, date_to, search_term, proxy) when is_proxy(proxy) do
    query = Query.new(date_from, date_to, %{words_all: search_term})
    Scraper.scrape(query, proxy)
  end

  @doc """
  Scrape a search phrase over a continuous range of dates.

    ## Example
      iex> query = %{words_all: ["nasa", "Atlas V rocket"]}
      ...
      iex> advanced_search(~D[2011-11-15], ~D[2011-11-19], query)
      {:ok, [%ExTweet.Parser.Tweet{}, ...]}

  The query map can take the following keys:
  - username
  - words_all
  - words_any
  - words_exclude

  Scraping with a proxy is optional.
  - :no_proxy     --> no proxy will be used
  - :random_proxy --> a random proxy will be selected from https://free-proxy-list.net/
  - user specified proxy `{Host, Port}` tuple

  Regarding the date range
  - date_from is inclusive
  - date_to is exclusive
  """
  @spec advanced_search(
          Date.t(),
          Date.t(),
          Query.optional_params(),
          :no_proxy | :random_proxy | Proxies.proxy()
        ) ::
          {:ok, [Tweet.t()]} | {:error, atom()}
  def advanced_search(date_from, date_to, query_params, proxy \\ :no_proxy)

  def advanced_search(date_from, date_to, query_params, proxy) when is_proxy(proxy) do
    query = Query.new(date_from, date_to, query_params)
    Scraper.scrape(query, proxy)
  end
end
