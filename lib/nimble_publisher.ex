defmodule NimblePublisher do
  @external_resource "README.md"
  @moduledoc "README.md"
             |> File.read!()
             |> String.split("<!-- MDOC !-->")
             |> Enum.fetch!(1)

  @doc false
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      {from, paths} = NimblePublisher.__extract__(__MODULE__, opts)

      for path <- paths do
        @external_resource Path.relative_to_cwd(path)
      end

      def __mix_recompile__? do
        unquote(from) |> Path.wildcard() |> Enum.sort() |> :erlang.md5() !=
          unquote(:erlang.md5(paths))
      end

      # TODO: Remove me once we require Elixir v1.11+.
      def __phoenix_recompile__?, do: __mix_recompile__?()
    end
  end

  @doc false
  def __extract__(module, opts) do
    from = Keyword.fetch!(opts, :from)
    as = Keyword.fetch!(opts, :as)
    paths = from |> Path.wildcard() |> Enum.sort()

    for highlighter <- Keyword.get(opts, :highlighters, []) do
      Application.ensure_all_started(highlighter)
    end

    builder = Keyword.fetch!(opts, :build)
    parser = Keyword.get(opts, :parser)
    converter = Keyword.get(opts, :html_converter)

    Code.ensure_compiled(builder)
    parser && Code.ensure_compiled(parser)
    converter && Code.ensure_compiled(converter)

    entries =
      paths
      |> Task.async_stream(
        fn path ->
          parsed_contents = parse_contents!(path, File.read!(path), parser)
          build_entry(builder, converter, path, parsed_contents, opts)
        end,
        timeout: :infinity
      )
      |> Enum.flat_map(fn
        {:ok, results} -> results
        _ -> []
      end)

    Module.put_attribute(module, as, entries)
    {from, paths}
  end

  @doc """
  Highlights all code blocks in an already generated HTML document.

  It uses Makeup and expects the existing highlighters applications to
  be already started.

  Options:

    * `:regex` - the regex used to find code blocks in the HTML document. The regex
      should have two capture groups: the first one should be the language name
      and the second should contain the code to be highlighted. The default
      regex to match with generated HTML documents is:

          ~r/<pre><code(?:\s+class="([^"\s]*)")?>([^<]*)<\/code><\/pre>/
  """
  defdelegate highlight(html, options \\ []), to: NimblePublisher.Highlighter

  defp build_entry(builder, converter, path, {_attrs, _body} = parsed_contents, opts) do
    build_entry(builder, converter, path, [parsed_contents], opts)
  end

  defp build_entry(builder, converter, path, parsed_contents, opts)
       when is_list(parsed_contents) do
    Enum.map(parsed_contents, fn {attrs, body} ->
      body =
        if converter do
          converter.convert(path, body, attrs, opts)
        else
          extname = path |> Path.extname() |> String.downcase()
          convert_body(path, extname, body, opts)
        end

      builder.build(path, attrs, body)
    end)
  end

  defp parse_contents!(path, contents, nil) do
    case parse_contents(path, contents) do
      {:ok, attrs, body} ->
        {attrs, body}

      {:error, message} ->
        raise """
        #{message}

        Each entry must have a map with attributes, followed by --- and a body. For example:

            %{
              title: "Hello World"
            }
            ---
            Hello world!

        """
    end
  end

  defp parse_contents!(path, contents, parser) do
    parser.parse(path, contents)
  end

  defp parse_contents(path, contents) do
    case :binary.split(contents, ["\n---\n", "\r\n---\r\n"]) do
      [_] ->
        {:error, "could not find separator --- in #{inspect(path)}"}

      [code, body] ->
        case Code.eval_string(code, []) do
          {%{} = attrs, _} ->
            {:ok, attrs, body}

          {other, _} ->
            {:error,
             "expected attributes for #{inspect(path)} to return a map, got: #{inspect(other)}"}
        end
    end
  end

  defp convert_body(path, extname, body, opts) when extname in [".md", ".markdown", ".livemd"] do
    earmark_opts = Keyword.get(opts, :earmark_options, %Earmark.Options{file: path})
    html = Earmark.as_html!(body, earmark_opts)

    case Keyword.get(opts, :highlighters, []) do
      [] -> html
      [_ | _] -> highlight(html)
    end
  end

  defp convert_body(_path, _extname, body, _opts) do
    body
  end
end
