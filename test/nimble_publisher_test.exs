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
               %{filename: "keyvalue.md"},
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
        from: "test/fixtures/markdown.{md,markdown}",
        as: :examples

      Enum.each(@examples, fn example ->
        assert example.attrs == %{hello: "world"}
        assert example.body == "<p>\nThis is a markdown <em>document</em>.</p>\n"
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

  test "passes earmark options to earmark - smartypants off" do
    defmodule Example do
      use NimblePublisher,
        build: Builder,
        from: "test/fixtures/nosyntax.md",
        as: :examples,
        earmark_options: %Earmark.Options{smartypants: false}

      assert hd(@examples).body =~ "<pre><code>IO.puts &quot;syntax&quot;</code></pre>"

      assert hd(@examples).body =~
               "And inline code: <code class=\"inline\">IO.puts &quot;syntax&quot;</code>"

      assert hd(@examples).body =~ "&quot;Smartypants quotes without inline code&quot;"
    end
  end

  test "passes earmark options to earmark - smartypants on" do
    defmodule Example do
      use NimblePublisher,
        build: Builder,
        from: "test/fixtures/nosyntax.md",
        as: :examples,
        earmark_options: %Earmark.Options{smartypants: true}

      assert hd(@examples).body =~ "<pre><code>IO.puts &quot;syntax&quot;</code></pre>"

      assert hd(@examples).body =~
               "And inline code: <code class=\"inline\">IO.puts “syntax”</code>"

      assert hd(@examples).body =~ "“Smartypants quotes without inline code”"
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

  test "properly parses key value attributes" do
    defmodule Example do
      use NimblePublisher,
        build: Builder,
        from: "test/fixtures/keyvalue.md",
        as: :highlights,
        highlighters: [:makeup_elixir]

      assert hd(@highlights).attrs == %{
               description: "string: with separator",
               hello: "world",
               tags: "comma,separated,values",
               multiple: "words in one line"
             }
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

  test "raises if invalid map" do
    assert_raise RuntimeError,
                 ~r/expected attributes for \"test\/fixtures\/invalid.map\" to return a map/,
                 fn ->
                   defmodule Example do
                     use NimblePublisher,
                       build: Builder,
                       from: "test/fixtures/invalid.map",
                       as: :example
                   end
                 end
  end

  test "raises if not key value pairs" do
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
end
