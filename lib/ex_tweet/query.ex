defmodule ExTweet.Query do
  @enforce_keys [:date_from, :date_to]
  defstruct [:username, :words_all, :words_any, :words_exclude] ++ @enforce_keys

  @type words_any() :: [[String.t()]]

  @type t() :: %__MODULE__{
          date_from: Date.t(),
          date_to: Date.t(),
          username: String.t() | nil,
          words_all: [String.t()] | nil,
          words_any: words_any() | nil,
          words_exclude: [String.t()] | nil
        }

  @type optional_params() :: %{
          optional(:username) => String.t(),
          optional(:words_all) => [String.t()],
          optional(:words_any) => words_any(),
          optional(:words_exclude) => [String.t()]
        }

  @spec new(Date.t(), Date.t(), optional_params()) :: t()
  def new(%Date{} = date_from, %Date{} = date_to, optional_params) do
    %__MODULE__{date_from: date_from, date_to: date_to}
    |> add_username(optional_params)
    |> add_words_all(optional_params)
    |> add_words_any(optional_params)
    |> add_words_exclude(optional_params)
  end

  defp add_username(query, %{username: nil}), do: query
  defp add_username(query, %{username: username}), do: Map.replace!(query, :username, username)
  defp add_username(query, %{}), do: query

  defp add_words_all(query, %{words_all: nil}), do: query
  defp add_words_all(query, %{words_all: term}), do: Map.replace!(query, :words_all, term)
  defp add_words_all(query, %{}), do: query

  defp add_words_any(query, %{words_any: nil}), do: query
  defp add_words_any(query, %{words_any: term}), do: Map.replace!(query, :words_any, term)
  defp add_words_any(query, %{}), do: query

  defp add_words_exclude(query, %{words_exclude: nil}), do: query

  defp add_words_exclude(query, %{words_exclude: term}),
    do: Map.replace!(query, :words_exclude, term)

  defp add_words_exclude(query, %{}), do: query
end
