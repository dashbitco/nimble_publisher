defmodule NimblePublisherTest do
  use ExUnit.Case, async: true

  doctest NimblePublisher

  defmodule Builder do
    def build(filename, attrs, body) do
      %{filename: filename, attrs: attrs, body: body}
    end
  end

  alias NimblePublisherTest.Example

  setup do
    File.rm_rf!("test/tmp")
    :code.purge(Example)
    :code.delete(Example)
    :ok
  end

  test "builds all matching entries" do
    defmodule Example do
      use NimblePublisher,
        build: Builder,
        from: "test/fixtures/**/*.md",
        as: :examples

      assert [
               %{filename: "crlf.md"},
               %{filename: "markdown.md"},
               %{filename: "nosyntax.md"},
               %{filename: "syntax.md"}
             ] =
               @examples
               |> update_in([Access.all(), :filename], &Path.basename/1)
               |> Enum.sort_by(& &1.filename)
    end
  end

  test "converts to markdown" do
    defmodule Example do
      use NimblePublisher,
        build: Builder,
        from: "test/fixtures/markdown.{md,markdown,livemd}",
        as: :examples

      Enum.each(@examples, fn example ->
        assert example.attrs == %{hello: "world"}
        assert String.match?(example.body, ~r"<p>\nThis is a markdown <em>document</em>.</p>\n")
      end)
    end
  end

  test "does not convert other extensions" do
    defmodule Example do
      use NimblePublisher,
        build: Builder,
        from: "test/fixtures/text.txt",
        as: :examples

      assert hd(@examples).attrs == %{hello: "world"}

      assert hd(@examples).body ==
               "This is a normal text.\n"
    end
  end

  test "handles code blocks" do
    defmodule Example do
      use NimblePublisher,
        build: Builder,
        from: "test/fixtures/nosyntax.md",
        as: :examples

      assert hd(@examples).attrs == %{syntax: "nohighlight"}
      assert hd(@examples).body =~ "<pre><code>IO.puts &quot;syntax&quot;</code></pre>"
    end
  end

  test "handles highlight blocks" do
    defmodule Example do
      use NimblePublisher,
        build: Builder,
        from: "test/fixtures/syntax.md",
        as: :highlights,
        highlighters: [:makeup_elixir]

      assert hd(@highlights).attrs == %{syntax: "highlight"}
      assert hd(@highlights).body =~ "<pre><code class=\"makeup elixir\">"
    end
  end

  test "does not require recompilation unless paths changed" do
    defmodule Example do
      use NimblePublisher,
        build: Builder,
        from: "test/fixtures/syntax.md",
        as: :highlights,
        highlighters: [:makeup_elixir]
    end

    refute Example.__mix_recompile__?()
  end

  test "requires recompilation if paths change" do
    defmodule Example do
      use NimblePublisher,
        build: Builder,
        from: "test/tmp/**/*.md",
        as: :highlights,
        highlighters: [:makeup_elixir]
    end

    refute Example.__mix_recompile__?()

    File.mkdir_p!("test/tmp")
    File.write!("test/tmp/example.md", "done!")

    assert Example.__mix_recompile__?()
  end

  test "allows for custom page parsing function returning {attrs, body}" do
    defmodule Parser do
      def parse(path, content) do
        body =
          content
          |> :binary.split("\nxxx\n")
          |> List.last()
          |> String.upcase()

        attrs = %{path: path, length: String.length(body)}

        {attrs, body}
      end
    end

    defmodule Example do
      use NimblePublisher,
        build: Builder,
        from: "test/fixtures/custom.parser",
        as: :custom,
        parser: Parser

      assert hd(@custom).body == "BODY\n"
      assert hd(@custom).attrs == %{path: "test/fixtures/custom.parser", length: 5}
    end
  end

  test "allows for custom page parsing function returning a list of {attrs, body}" do
    defmodule MultiParser do
      def parse(path, contents) do
        contents
        |> String.split("\n***\n")
        |> Enum.map(fn content ->
          body =
            content
            |> :binary.split("\nxxx\n")
            |> List.last()
            |> String.upcase()

          attrs = %{path: path, length: String.length(body)}

          {attrs, body}
        end)
      end
    end

    defmodule Example do
      use NimblePublisher,
        build: Builder,
        from: "test/fixtures/custom.multi.parser",
        as: :custom,
        parser: MultiParser

      assert hd(@custom).body == "BODY\n"
      assert hd(@custom).attrs == %{path: "test/fixtures/custom.multi.parser", length: 5}
      assert length(@custom) == 3
    end
  end

  test "allows for custom markdown parsing function returning parsed html" do
    defmodule MarkdownConverter do
      def convert_body(extname, _body, opts) do
        from = Keyword.get(opts, :from)

        "<p>This is a custom markdown converter from a #{extname} file, from the #{from} file</p>\n"
      end
    end

    defmodule Example do
      use NimblePublisher,
        build: Builder,
        from: "test/fixtures/markdown.md",
        as: :custom,
        converter: MarkdownConverter

      assert hd(@custom).body ==
               "<p>This is a custom markdown converter from a .md file, from the test/fixtures/markdown.md file</p>\n"
    end
  end

  test "raises if missing separator" do
    assert_raise RuntimeError,
                 ~r/could not find separator --- in "test\/fixtures\/invalid.noseparator"/,
                 fn ->
                   defmodule Example do
                     use NimblePublisher,
                       build: Builder,
                       from: "test/fixtures/invalid.noseparator",
                       as: :example
                   end
                 end
  end

  test "raises if not a map" do
    assert_raise RuntimeError,
                 ~r/expected attributes for \"test\/fixtures\/invalid.nomap\" to return a map/,
                 fn ->
                   defmodule Example do
                     use NimblePublisher,
                       build: Builder,
                       from: "test/fixtures/invalid.nomap",
                       as: :example
                   end
                 end
  end

  test "highlights code blocks" do
    higlighters = [:makeup_elixir, :makeup_erlang]
    input = "<pre><code class=\"elixir\">IO.puts(\"Hello World\")</code></pre>"
    output = NimblePublisher.highlight(input, higlighters)

    assert output =~ "<pre><code class=\"makeup elixir\"><span class=\"nc\">IO"
  end

  test "highlights code blocks with custom regex" do
    highlighters = [:makeup_elixir]
    input = "<code lang=\"elixir\">IO.puts(\"Hello World\")</code>"

    output =
      NimblePublisher.highlight(
        input,
        highlighters,
        regex: ~r/<code(?:\s+lang="(\w*)")?>([^<]*)<\/code>/
      )

    assert output =~ "<pre><code class=\"makeup elixir\"><span class=\"nc\">"
  end
end
