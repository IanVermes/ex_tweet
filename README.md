# ex_tweet
Find tweets. Not just now but in the past too. No API access needed!

Things you can do:
* search for all the tweets of a single user
* search for all the tweets on specific subject (restricted by date range)
* search for all the tweets with a query more advanced than the official Twitter
  search bar (restricted by date range)

## Installation instructions
To you `mix.exs` add

```elixir
defp deps do
  [
    {:ex_tweet, git: "git@github.com:IanVermes/ex_tweet.git"},
  ]
end
```

If there is interest, I'll package the repo and publish it on `hex.pm`

## Usage: three API functions

### Search for tweets by a single user

A search for tweets from a specific user, across a continuous range of dates.

```elixir
iex(1)> ExTweet.user_tweets(~D[2020-01-10], ~D[2020-01-15], "BBCNews")
{:ok, [%ExTweet.Parser.Tweet{}, ...]}  # 244 tweets
```

### Search for tweets with a simple search query

A search for tweets that contain the query _words_ or _phrases_ in the tweet
text, across a continuous range of dates.

Tweets with the phrases `wimbledon final` and `double`
```elixir
iex(1)> ExTweet.simple_search(~D[2016-07-08], ~D[2016-07-11], ["wimbledon final", "doubles"])
{:ok, [%ExTweet.Parser.Tweet{}, ...]}  # 65 tweets
```

Tweets with the words `wimbledon`, `final` and `double`
```elixir
ExTweet.simple_search(~D[2016-07-08], ~D[2016-07-11], ["wimbledon", "final", "doubles"])
{:ok, [%ExTweet.Parser.Tweet{}, ...]}  # 2496 tweets
```

### Search for tweets with a configurable search query

A search for tweets that contain *all* the query words in their text, across a
continuous range of dates.

```elixir
iex(1)> query = %{words_all: ["wimbledon final", "doubles"], words_any: [["mens", "gentlemen"]]}

iex(2)> ExTweet.advanced_search(~D[2016-07-08], ~D[2016-07-11], query)
{:ok, [%ExTweet.Parser.Tweet{}, ...]}  # 8 tweets
```

#### Configurable query

A map with any of these keys:
* `:username` - string value
* `:words_all` - lists of words or phrases
* `:words_exclude` - lists of words or phrases
* `:words_any` - list of lists of words or phrases

#### Word vs Phrase

* A word is a string of characters without spaces like `"hello"`
* A phrase is a series of characters with a spaces like `"hello world"`
  or multiple spaces like `"my hello world"`

A phrase will lead to a search for the exact phrase

### Examples

```elixir
%{
    words_all: ["wimbledon final", "doubles"],
    words_any: [["mixed", "mens"]]
}
```

This query between 2016-07-08 & 2016-07-11 got 26 tweets. Examples:
* *Congratulations to Heather Watson and Henri kontinen on Winning the mixed
  doubles wimbledon final. Well done 👍 🎾*
* *What a day for Team GB- Lewis Hamilton winning - Andy Murray winning the
  Wimbledon Final and Heather Watson winning the Mixed Doubles Final*
* *The day gets better for the British! Heather Watson wins in the mixed doubles
  #Wimbledon final 👏🏼 🇬🇧 🏆*

```elixir
%{
    words_all: ["doubles"],
    words_any: [
        ["wheelchair", "paralympic"],
        ["tennis", "wimbledon"],
        ["mixed", "men", "women"]
    ]
}
```

This query between 2016-07-08 & 2016-07-11 got 372 tweets. Examples:
* *Your women's Wimbledon Wheelchair Doubles Champion Jordanne Whiley... 🏆 🏆
  🏆 #3rdTitle #Wimbledon #WheelchairTennis*
* *Super Sunday of Tennis. Men's single for Murray & Wheelchair for Reid. Mixed
  doubles for Watson & Whibley wheelchair doubles. #brittennis*
* *Today has been a great day for GB Tennis...Wheelchair Champions in singles
  and doubles, Champions mens singles and mixed doubles #Wimbledon*

```elixir
%{
  words_any: [
    ["wimbledon", "tour de france"],
    ["andy murray", "chris froome"],
    ["shock", "surprise"]
  ]
}
```

This query between 2016-07-08 & 2016-07-11 got 29 tweets. Examples:
* *Andy Murray's hopes of completing the calendar year Grand Slam of losing
  finals shattered in shock win #Wimbledon*
* *Chris Froome launches surprise bid to claim overall lead in Tour de France
  via @SCMP_News*
* *Tour de France standings 2016: Chris Froome takes yellow jersey with a
  surprise attack on Stage 8 - SB Nation*

```elixir
%{
    words_exclude: ["wimbledon", "tennis", "sw19"],
    words_any: [
      ["pimms", "strawberries"],
      ["weekend", "picnic"]
    ]
}
```

This query between 2016-07-08 & 2016-07-11 got 108 tweets. Examples:
* *An incredible weekend at Silverstone. Fast cars, lots of Pimms & amazing
  company! Plus a British winner. Makes the 6.15am bedtime worth it!*
* *#birthdays, #bbqs, #beers and #pimms What a way to start the weekend*
* *First plantings at new house. Strawberries transplanted from old place.
  Another weekend gone*

## Usage: Tweet struct

Special features:
* Extraction of in-lined and embedded links
* Parsing of `@USER`, `#hashtags` and emojis

```elixir
   %ExTweet.Parser.Tweet{
     datetime: ~U[2016-07-10 15:35:58Z],
     id: 752164466662510592,
     links: ["http://bbc.in/29pKmeY"],
     text: "Milos Raonic produced the fastest serve of #Wimbledon No problem for Murray, though Watch:",
     url: "https://twitter.com/BBCSport/status/752164466662510592",
     user_id: 265902729,
     username: "BBCSport"
   }
```

## Configuration

If you wish to change the configuration settings of ExTweet, include
`config: :ex_tweet, :request_settings, ...` in your projects config file.
