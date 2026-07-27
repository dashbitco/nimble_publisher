defmodule Builder do
  def build(filename, attrs, body) do
    %{filename: filename, attrs: attrs, body: body}
  end
end
