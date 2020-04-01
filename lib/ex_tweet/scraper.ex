defmodule ExTweet.Scraper do
  alias ExTweet.{UrlFormat, Headers, Parser, Proxies, Query, Filter}

  require Logger

  @config Application.fetch_env!(:ex_tweet, :request_settings)
  @max_reattempts Keyword.fetch!(@config, :max_reattempts)
  @max_timeout_ms Keyword.fetch!(@config, :max_timeout_ms)
  @reattempt_sleep_ms Keyword.fetch!(@config, :reattempt_sleep_ms)

  @name __MODULE__

  ## API

  @spec scrape(Query.t(), :no_proxy | :random_proxy | {any, any}) ::
          {:error, any} | {:ok, any}
  def scrape(query, proxy) do
    Logger.info("#{@name} query=#{inspect(query)}")

    init_loop(query, proxy)
  end

  ## Private - main loop

  defp init_loop(query, proxy) do
    query_tuple = {:ok, query}
    scrape? = true
    cursor = nil
    tweets = []

    {:ok, cookiejar} = CookieJar.new()
    request_settings = %{cookiejar: cookiejar, proxy: resolve_proxy(proxy)}
    Logger.debug("#{@name} proxy=#{inspect(request_settings.proxy)}")

    loop(query_tuple, cursor, request_settings, scrape?, tweets)
  end

  defp loop({:error, reason}, _cursor, _request_settings, _scrape?, _tweets) do
    # Use query tuple argument to carry errors through the loop, as they will
    # immediately terminate the loop after an HTML request at the next scrape
    # attempt.
    Logger.error("#{@name} complete reason=#{reason}")
    {:error, reason}
  end

  defp loop({:ok, query}, _cursor, _request_settings, false, tweets) do
    # Tweets have been accumulated, no further scrape possible.
    Logger.info("#{@name} complete tweet_count=#{length(tweets)}")
    filtered_tweets = Filter.filter(tweets, query)
    Logger.info("#{@name} filtered tweet_count=#{length(filtered_tweets)}")
    {:ok, filtered_tweets}
  end

  defp loop(
         {:try_again, %{try_again: reason} = query},
         cursor,
         request_settings,
         scrape?,
         tweets
       )
       when reason in [:proxy, :timeout, :too_many_requests] do
    # Under some situations it makes sense to retry the same scrape and take an
    # remedial steps to adjust the arguments/parameters of the scraper. The URL
    # that failed in the previous attempt will be used in the retry.
    {updated_query_tuple, updated_request_settings} = try_again_handler(query, request_settings)
    # Tail end recursion
    loop(updated_query_tuple, cursor, updated_request_settings, scrape?, tweets)
  end

  defp loop(
         {:ok, query},
         cursor,
         request_settings,
         true = scrape?,
         tweets
       ) do
    # Scrape the next json, parse tweets and decide whether to scrape again

    # Setup the request to Twitter
    url = UrlFormat.json_url(query, cursor)
    headers = Headers.generate_headers(url)
    Logger.debug("#{@name} request url=#{url}")

    response =
      get_twitter_response(url, request_settings, headers)
      |> parse_response()

    # Update the loop/5 arguments using the response from Twitter
    updated_query_tuple = update_query_tuple(query, response)
    updated_scrape? = update_scrape?(scrape?, response)
    updated_tweets = updated_tweets_acc(tweets, response)
    updated_cursor = update_cursor(cursor, response)

    # Tail-end recursive request/response loop
    Logger.debug("#{@name} again scrape?=#{updated_scrape?}")
    loop(updated_query_tuple, updated_cursor, request_settings, updated_scrape?, updated_tweets)
  end

  ## Private - Loop helpers

  @spec get_twitter_response(
          String.t(),
          %{
            proxy: :no_proxy | Proxies.proxy(),
            cookiejar: GenServer.server()
          },
          HTTPoison.headers()
        ) ::
          {:ok, HTTPoison.Response.t() | HTTPoison.AsyncResponse.t()}
          | {:error, HTTPoison.Error.t()}
  defp get_twitter_response(url, %{proxy: :no_proxy, cookiejar: cookiejar}, headers) do
    CookieJar.HTTPoison.get(cookiejar, url, headers,
      timeout: @max_timeout_ms,
      recv_timeout: @max_timeout_ms
    )
  end

  defp get_twitter_response(url, %{proxy: {ip, port}, cookiejar: cookiejar}, headers) do
    proxy = {ip, String.to_integer(port)}

    CookieJar.HTTPoison.get(cookiejar, url, headers,
      proxy: proxy,
      timeout: @max_timeout_ms,
      recv_timeout: @max_timeout_ms
    )
  end

  defp parse_response({:ok, %{status_code: 200, body: body} = resp}) do
    result = Parser.parse(body)

    Logger.debug(
      "#{@name} response status=#{resp.status_code}, tweet_count=#{length(result.tweets)}"
    )

    {:ok, result}
  end

  defp parse_response({:ok, %{status_code: 429, body: _body} = resp}) do
    Logger.warn("#{@name} response status=#{resp.status_code}, too_many_requests")
    {:try_again, :too_many_requests}
  end

  defp parse_response({:ok, %{status_code: 503, body: _body} = resp}) do
    # Getting a 503 is similar to a 429, except we may want to proxy hop if
    # using a proxy. So handle it like we handle timeouts.
    Logger.warn("#{@name} response status=#{resp.status_code}, retry after...")
    {:try_again, :timeout}
  end

  defp parse_response({:ok, %{status_code: status, body: _body}}) do
    Logger.error("#{@name} response status=#{status}")
    {:error, :response_error}
  end

  defp parse_response({:error, %{reason: :proxy_error}}) do
    Logger.warn("#{@name} response proxy_error")
    {:try_again, :proxy}
  end

  defp parse_response({:error, %{reason: :econnrefused}}) do
    Logger.warn("#{@name} response econnrefused")
    {:try_again, :proxy}
  end

  defp parse_response({:error, %{reason: {:tls_alert, _}}}) do
    # SSL certification issue
    Logger.warn("#{@name} response tls_alert")
    {:try_again, :proxy}
  end

  defp parse_response({:error, %{reason: :etimedout}}) do
    # `etimedout` is a hackney derived timeout
    Logger.warn("#{@name} response etimedout")
    {:try_again, :timeout}
  end

  defp parse_response({:error, %{reason: :timeout}}) do
    Logger.warn("#{@name} response timeout")
    {:try_again, :timeout}
  end

  defp parse_response({:error, %{reason: :closed}}) do
    Logger.warn("#{@name} response closed")
    {:try_again, :too_many_requests}
  end

  defp parse_response({:error, %{reason: reason}}) do
    Logger.error("#{@name} response reason=#{inspect(reason)}")
    {:error, :request_error}
  end

  defp update_query_tuple(query, {:ok, _response}), do: {:ok, query}
  defp update_query_tuple(_, {:error, reason}), do: {:error, reason}

  defp update_query_tuple(query, {:try_again, condition}),
    do: {:try_again, Map.put(query, :try_again, condition)}

  defp updated_tweets_acc(tweets, {:ok, response}), do: tweets ++ response.tweets
  defp updated_tweets_acc(tweets, {_, _}), do: tweets

  defp update_scrape?(_scrape?, {:ok, response}), do: response.has_items? or response.has_tweets?
  defp update_scrape?(scrape?, {_, _}), do: scrape?

  defp update_cursor(_cursor, {:ok, response}), do: response.cursor
  defp update_cursor(cursor, {_, _}), do: cursor

  defp resolve_proxy(:random_proxy), do: Proxies.random_proxy()
  defp resolve_proxy(:no_proxy), do: :no_proxy
  defp resolve_proxy({_ip, _port} = proxy), do: proxy

  defp try_again_handler(%{try_again: try_again_reason} = query, request_settings) do
    Logger.debug("#{@name} reattempt reason=#{inspect(try_again_reason)}")

    updated_request_settings =
      request_settings
      |> try_again_solution(try_again_reason)
      |> increment_settings_counter(try_again_reason)

    # Check if retried too many times and change the query_tuple to determine
    # the next step of the loop
    query_tuple =
      if too_many_retries?(updated_request_settings, try_again_reason) do
        try_again_error(try_again_reason)
      else
        # Drop the `:try_again` key so as to clean the `query` map.
        {:ok, Map.delete(query, :try_again)}
      end

    {query_tuple, updated_request_settings}
  end

  defp try_again_solution(request_settings, :proxy) do
    current_proxy = request_settings.proxy
    replacement_proxy = Proxies.random_proxy()

    patched_settings =
      cond do
        replacement_proxy == :no_proxy ->
          # This case prevents the infinite loop where `:no_proxy == :no_proxy`
          %{request_settings | proxy: replacement_proxy}

        replacement_proxy == current_proxy ->
          try_again_solution(request_settings, :proxy)

        true ->
          %{request_settings | proxy: replacement_proxy}
      end

    Logger.debug("#{@name} reattempt :proxy proxy=#{inspect(patched_settings.proxy)}")
    patched_settings
  end

  defp try_again_solution(request_settings, :too_many_requests) do
    Logger.debug("#{@name} reattempt :too_many_requests sleeping")
    :timer.sleep(@reattempt_sleep_ms)
    Logger.debug("#{@name} reattempt :too_many_requests waking_after=#{@reattempt_sleep_ms} (ms)")
    request_settings
  end

  defp try_again_solution(request_settings, :timeout) do
    if request_settings.proxy == :no_proxy do
      Logger.debug("#{@name} reattempt :timeout, sleep")
      :timer.sleep(@reattempt_sleep_ms)
      Logger.debug("#{@name} reattempt :timeout, waking_after=#{@reattempt_sleep_ms} (ms)")
      request_settings
    else
      Logger.debug("#{@name} reattempt :timeout, try different proxy")
      try_again_solution(request_settings, :proxy)
    end
  end

  defp try_again_error(:proxy), do: {:error, :too_many_proxies}
  defp try_again_error(:too_many_requests), do: {:error, :too_many_requests}
  defp try_again_error(:timeout), do: {:error, :too_many_timeouts}

  defp increment_settings_counter(request_settings, :proxy) do
    Map.update(request_settings, :try_again_count_proxies, 0, fn count -> count + 1 end)
  end

  defp increment_settings_counter(request_settings, :too_many_requests) do
    Map.update(request_settings, :try_again_count_too_many_requests, 0, fn count -> count + 1 end)
  end

  defp increment_settings_counter(request_settings, :timeout) do
    Map.update(request_settings, :try_again_count_timeout, 0, fn count -> count + 1 end)
  end

  defp too_many_retries?(request_settings, :proxy) do
    Map.get(request_settings, :try_again_count_proxies, 0) > @max_reattempts
  end

  defp too_many_retries?(request_settings, :too_many_requests) do
    Map.get(request_settings, :try_again_count_too_many_requests, 0) > @max_reattempts
  end

  defp too_many_retries?(request_settings, :timeout) do
    Map.get(request_settings, :try_again_count_timeout, 0) > @max_reattempts
  end
end
