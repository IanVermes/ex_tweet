defmodule ExTweet.Proxies do
  @proxy_url "https://free-proxy-list.net/"
  @type proxy :: {String.t(), String.t()}

  @name __MODULE__

  ## API

  require Logger

  @spec random_proxy :: __MODULE__.proxy() | :no_proxy
  def random_proxy() do
    HTTPoison.get(@proxy_url)
    |> handle_response()
  end

  ## Private

  defp handle_response({:ok, %{status_code: 200, body: body}}) do
    {:ok, html} = Floki.parse_document(body)

    parse_proxies(html)
    |> Enum.random()
  end

  defp handle_response(_) do
    Logger.warn("#{@name} could not get proxy")
    # If its not possible to get a proxy for any reason, then do not use a
    # proxy.
    :no_proxy
  end

  defp parse_proxies(html) do
    ips_and_ports =
      for row <- Floki.find(html, "table#proxylisttable tr") do
        ip_address = Floki.find(row, "td:nth-child(1)") |> Floki.text()
        port = Floki.find(row, "td:nth-child(2)") |> Floki.text()
        https_s = Floki.find(row, "td:nth-child(7)") |> Floki.text()

        https? =
          case https_s do
            "yes" -> true
            "no" -> false
            _ -> false
          end

        {ip_address, port, https?}
      end

    ips_and_ports
    |> Stream.filter(fn
      {"", _port, _} -> false
      {_ip, "", _} -> false
      {_ip, _port, _} -> true
    end)
    |> Enum.filter(fn
      # Keep only HTTPS proxies
      {_ip, _port, false} -> false
      {_ip, _port, true} -> true
    end)
    |> Enum.map(fn {ip, port, _} -> {ip, port} end)
  end
end
