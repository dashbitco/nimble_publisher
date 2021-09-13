# NimblePublisher

[Online Documentation](https://hexdocs.pm/nimble_publisher).

<!-- MDOC !-->

`NimblePublisher` is a minimal filesystem-based publishing engine with Markdown support and
code highlighting.

```elixir
use NimblePublisher,
  build: Article,
  from: Application.app_dir(:app_name, "priv/articles/**/*.md"),
  as: :articles,
  highlighters: [:makeup_elixir, :makeup_erlang]
```

The example above will get all articles in the given directory,
call `Article.build/3` for each article, passing the filename,
the metadata, and the article body, and define a module attribute
named `@articles` with all built articles returned by the
`Article.build/3` function.

Each article in the articles directory must have the format:

    %{
      title: "Hello world"
    }
    ---
    Body of the "Hello world" article.

    This is a *markdown* document with support for code highlighters:

    ```elixir
    IO.puts "hello world".
    ```

## Options

  * `:build` - the name of the module that will build each entry

  * `:from` - a wildcard pattern where to find all entries. Files with the
    `.md` or `.markdown` extension will be converted to Markdown with
    `Earmark`. Other files will be kept as is.

  * `:as` - the name of the module attribute to store all built entries

  * `:highlighters` - which code highlighters to use. `NimblePublisher`
    uses `Makeup` for syntax highlighting and you will need to add its
    `.css` classes. You can generate the CSS classes by calling
    `Makeup.stylesheet(:vim_style, "makeup")` inside `iex -S mix`.
    You can replace `:vim_style` by any style of your choice
    [defined here](https://hexdocs.pm/makeup/Makeup.Styles.HTML.StyleMap.html).

  * `:earmark_options` - an [`%Earmark.Options{}`](https://hexdocs.pm/earmark/Earmark.Options.html) struct

  * `:parser` - custom module with a `parse/2` function that receives the file path
    and content as params. It must return a 2 element tuple with attributes and body.

## Examples

Let's see a complete example. First add `nimble_publisher` with
the desired highlighters as a dependency:

    def deps do
      [
        {:nimble_publisher, "~> 0.1.0"},
        {:makeup_elixir, ">= 0.0.0"},
        {:makeup_erlang, ">= 0.0.0"}
      ]
    end

In this example, we are building a blog. Each post stays in the
"posts" directory with the format:

    /posts/YEAR/MONTH-DAY-ID.md

A typical blog post will look like this:

    # /posts/2020/04-17-hello-world.md
    %{
      title: "Hello world!",
      author: "José Valim",
      tags: ~w(hello),
      description: "Let's learn how to say hello world"
    }
    ---
    This is the post.

Therefore, we will define a Post struct that expects all of the fields
above. We will also have a `:date` field that we will build from the
filename. Overall, it will look like this:

```elixir
defmodule MyApp.Blog.Post do
  @enforce_keys [:id, :author, :title, :body, :description, :tags, :date]
  defstruct [:id, :author, :title, :body, :description, :tags, :date]

  def build(filename, attrs, body) do
    [year, month_day_id] = filename |> Path.rootname() |> Path.split() |> Enum.take(-2)
    [month, day, id] = String.split(month_day_id, "-", parts: 3)
    date = Date.from_iso8601!("#{year}-#{month}-#{day}")
    struct!(__MODULE__, [id: id, date: date, body: body] ++ Map.to_list(attrs))
  end
end
```

Now, we are ready to define our `MyApp.Blog` with `NimblePublisher`:

```elixir
defmodule MyApp.Blog do
  alias MyApp.Blog.Post

  use NimblePublisher,
    build: Post,
    from: Application.app_dir(:my_app, "priv/posts/**/*.md"),
    as: :posts,
    highlighters: [:makeup_elixir, :makeup_erlang]

  # The @posts variable is first defined by NimblePublisher.
  # Let's further modify it by sorting all posts by descending date.
  @posts Enum.sort_by(@posts, & &1.date, {:desc, Date})

  # Let's also get all tags
  @tags @posts |> Enum.flat_map(& &1.tags) |> Enum.uniq() |> Enum.sort()

  # And finally export them
  def all_posts, do: @posts
  def all_tags, do: @tags
end
```

**Important**: Avoid injecting the `@posts` attribute into multiple functions,
as each call will make a complete copy of all posts. For example, if you want
to show define `recent_posts()` as well as `all_posts()`, DO NOT do this:

```elixir
def all_posts, do: @posts
def recent_posts, do: Enum.take(@posts, 3)
```

Instead do this:

```elixir
def all_posts, do: @posts
def recent_posts, do: Enum.take(all_posts(), 3)
```

### Other helpers

You may want to define other helpers to traverse your published resources.
For example, if you want to get posts by ID or with a given tag, you can
define additional functions as shown below:

```elixir
defmodule NotFoundError do
  defexception [:message, plug_status: 404]
end

def get_post_by_id!(id) do
  Enum.find(all_posts(), &(&1.id == id)) ||
    raise NotFoundError, "post with id=#{id} not found"
end

def get_posts_by_tag!(tag) do
  case Enum.filter(all_posts(), &(tag in &1.tags)) do
    [] -> raise NotFoundError, "posts with tag=#{tag} not found"
    posts -> posts
  end
end
```

### Custom parser

You may want to define a custom function to parse the content of your files.

```elixir
  use NimblePublisher,
    ...
    parser: Parser,

defmodule Parser do
  def parse(path, contents) do
    [attrs, body] = :binary.split(contents, ["\n---\n"])
    {Jason.decode!(attrs), body}
  end
end
```

The `parse/2` function from this module receives the file path and content as params.
It must return a 2 element tuple with attributes and body.

### Live reloading

If you are using Phoenix, you can enable live reloading by simply telling Phoenix to watch the “posts” directory. Open up "config/dev.exs", search for `live_reload:` and add this to the list of patterns:

```elixir
live_reload: [
  patterns: [
    ...,
    ~r"posts/*/.*(md)$"
  ]
]
```

## Learn more

  * [Dashbit's blog post which was the foundation for NimblePublisher](https://dashbit.co/blog/welcome-to-our-blog-how-it-was-made)
  * [Elixir School's lesson on using NimblePublisher, complete with Phoenix integration](https://elixirschool.com/en/lessons/libraries/nimble-publisher/)

<!-- MDOC !-->

## Nimble*

All nimble libraries by Dashbit:

  * [NimbleCSV](https://github.com/dashbitco/nimble_csv) - simple and fast CSV parsing
  * [NimbleOptions](https://github.com/dashbitco/nimble_options) - tiny library for validating and documenting high-level options
  * [NimbleParsec](https://github.com/dashbitco/nimble_parsec) - simple and fast parser combinators
  * [NimblePool](https://github.com/dashbitco/nimble_pool) - tiny resource-pool implementation
  * [NimblePublisher](https://github.com/dashbitco/nimble_publisher) - a minimal filesystem-based publishing engine with Markdown support and code highlighting
  * [NimbleTOTP](https://github.com/dashbitco/nimble_totp) - tiny library for generating time-based one time passwords (TOTP)

## License

Copyright 2020 Dashbit

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

      http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
