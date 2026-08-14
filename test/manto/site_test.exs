defmodule Manto.SiteTest do
  use ExUnit.Case, async: false
  alias Manto.Site

  test "returns defaults when no config is present" do
    path =
      Path.join(System.tmp_dir!(), "manto-missing-#{System.unique_integer([:positive])}.json")

    config = Site.config(path: path)

    assert config == %{
             "title" => "Manto",
             "description" => "A local-first Markdown site",
             "base_url" => ""
           }
  end

  test "merges manto.json over app env over defaults" do
    previous = Application.get_env(:manto, :site)

    Application.put_env(:manto, :site, %{title: "Env Title", description: "Env description"})

    on_exit(fn ->
      if previous do
        Application.put_env(:manto, :site, previous)
      else
        Application.delete_env(:manto, :site)
      end
    end)

    path = Path.join(System.tmp_dir!(), "manto-config-#{System.unique_integer([:positive])}.json")

    File.write!(path, ~s({"title": "File Title", "base_url": "https://example.com"}))
    on_exit(fn -> File.rm(path) end)

    config = Site.config(path: path)

    assert config["title"] == "File Title"
    assert config["description"] == "Env description"
    assert config["base_url"] == "https://example.com"
  end

  test "raises when manto.json is not a JSON object" do
    path = Path.join(System.tmp_dir!(), "manto-bad-#{System.unique_integer([:positive])}.json")
    File.write!(path, "not json")
    on_exit(fn -> File.rm(path) end)

    assert_raise ArgumentError, ~r/expected a JSON object/, fn ->
      Site.config(path: path)
    end
  end
end
