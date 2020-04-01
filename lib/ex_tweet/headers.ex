defmodule ExTweet.Headers do
  @headers_base [
    {"Host", "twitter.com"},
    {"Accept", "application/json, text/javascript, */*; q=0.01"},
    {"Accept-Language", "en-US,en;q=0.5"},
    {"X-Requested-With", "XMLHttpRequest"},
    {"Connection", "keep-alive"}
  ]

  @user_agents [
    "Mozilla/5.0 (Windows NT 6.1; WOW64; rv:63.0) Gecko/20100101 Firefox/63.0",
    "Mozilla/5.0 (Windows NT 6.1; WOW64; rv:62.0) Gecko/20100101 Firefox/62.0",
    "Mozilla/5.0 (Windows NT 6.1; WOW64; rv:61.0) Gecko/20100101 Firefox/61.0",
    "Mozilla/5.0 (Windows NT 6.1; Win64; x64; rv:63.0) Gecko/20100101 Firefox/63.0",
    "Mozilla/5.0 (Windows NT 6.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/70.0.3538.77 Safari/537.36",
    "Mozilla/5.0 (Windows NT 6.3; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/70.0.3538.77 Safari/537.36",
    "Mozilla/5.0 (Windows NT 6.1; Trident/7.0; rv:11.0) like Gecko",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_6) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/12.0 Safari/605.1.15"
  ]

  ## API
  @doc """
  Request headers are generated with a randomised user-agent and need a URL referer.
  """
  @spec generate_headers(String.t()) :: HTTPoison.Request.headers()
  def generate_headers(url) do
    [random_user_agent(), referer(url) | @headers_base]
    |> Map.new()
  end

  ## Private

  defp random_user_agent() do
    {"User-Agent", Enum.random(@user_agents)}
  end

  defp referer(url) do
    {"Referer", url}
  end
end
