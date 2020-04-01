defmodule ExTweet.MixProject do
  use Mix.Project

  def project do
    [
      app: :ex_tweet,
      version: "0.2.3",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:jason, "~> 1.0"},
      {:httpoison, "~> 1.6"},
      {:floki, "~> 0.26.0"},
      # Cookie handling for HTTPPoison request calls
      {:cookie_jar, "~> 1.0"},
      # Dev tools
      {:dialyxir, "~> 1.0.0-rc.7", only: [:dev], runtime: false}
    ]
  end
end
