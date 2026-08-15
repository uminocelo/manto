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
             "base_url" => "",
             "vault_path" => "priv/content"
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

  test "save/2 writes settings and merges with existing keys" do
    path = Path.join(System.tmp_dir!(), "manto-save-#{System.unique_integer([:positive])}.json")
    on_exit(fn -> File.rm(path) end)

    assert :ok = Site.save(%{"title" => "My Site", "vault_path" => "notes"}, path: path)
    assert Site.config(path: path)["title"] == "My Site"
    assert Site.config(path: path)["vault_path"] == "notes"

    assert :ok = Site.save(%{"base_url" => "https://example.com"}, path: path)

    config = Site.config(path: path)
    assert config["title"] == "My Site"
    assert config["vault_path"] == "notes"
    assert config["base_url"] == "https://example.com"
  end

  test "save/2 writes a file that later takes precedence over defaults" do
    path =
      Path.join(
        System.tmp_dir!(),
        "manto-save-defaults-#{System.unique_integer([:positive])}.json"
      )

    on_exit(fn -> File.rm(path) end)

    Site.save(%{"description" => "My notes"}, path: path)

    config = Site.config(path: path)
    assert config["description"] == "My notes"
    assert config["title"] == "Manto"
    assert config["vault_path"] == "priv/content"
  end
end
