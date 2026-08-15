defmodule Mix.Tasks.Manto.Release do
  use Mix.Task

  alias Mix.Project

  @shortdoc "Builds a distributable Manto release tarball"

  @moduledoc """
  Packages Manto into a self-contained release tarball.

      mix manto.release
      mix manto.release --version 0.2.0

  Runs `assets.deploy` (minified assets + digest manifest) and `mix release`
  in the `prod` environment, then packs `_build/prod/rel/manto` — including
  the bundled BEAM runtime — into `dist/manto-v<version>.tar.gz`. A
  `bin/server` convenience script and a short `README.txt` are added to the
  package.

  End users don't need Elixir or Mix installed. After extracting they run:

      cd manto-v<version>
      ./bin/server

  (or `PHX_SERVER=true bin/manto start`) and open http://localhost:4000.

  Options:

    * `--version`, `-v` - version string used in the package name
      (default: the app version from `mix.exs`)
  """

  @impl true
  def run(args) do
    {opts, _} =
      OptionParser.parse!(args,
        strict: [version: :string],
        aliases: [v: :version]
      )

    version = opts |> Keyword.get(:version, Project.config()[:version]) |> to_string() |> trim_v()
    package = "manto-v#{version}"
    dist_dir = Path.expand("dist")
    File.mkdir_p!(dist_dir)

    # compile first: colocated LiveView JS (`phoenix-colocated/<app>`) is only
    # emitted during compilation, and a stale prod build dir can miss it
    sh("mix", ["compile"], env: prod_env())

    colocated = Path.expand("_build/prod/phoenix-colocated/manto")

    unless File.dir?(colocated) do
      sh("mix", ["compile", "--force"], env: prod_env())
    end

    sh("mix", ["assets.deploy"], env: prod_env())
    sh("mix", ["release", "--overwrite"], env: prod_env())

    release_dir = Path.expand("_build/prod/rel/manto")

    unless File.dir?(release_dir) do
      Mix.raise("Release not found at #{release_dir}")
    end

    package_dir = Path.join(dist_dir, package)
    File.rm_rf!(package_dir)
    File.cp_r!(release_dir, package_dir)

    write_bin_server(package_dir)
    write_readme(package_dir, version)

    tarball = Path.join(dist_dir, "#{package}.tar.gz")
    File.rm(tarball)
    sh("tar", ["-czf", "#{package}.tar.gz", package], cd: dist_dir)

    size = format_size(File.stat!(tarball).size)

    Mix.shell().info("""
    Built #{package}.tar.gz (#{size}) into #{dist_dir}

    To run Manto on a fresh machine:
      tar -xzf #{package}.tar.gz
      cd #{package}
      ./bin/server

    Then open http://localhost:4000 (editor at /editor).
    """)
  end

  defp trim_v(version),
    do: if(String.starts_with?(version, "v"), do: String.slice(version, 1..-1//1), else: version)

  # full environment so `mix` still finds its executables on PATH
  defp prod_env, do: System.get_env() |> Map.put("MIX_ENV", "prod")

  defp sh(cmd, args, opts) do
    env = Keyword.get(opts, :env, System.get_env())

    {output, status} =
      System.cmd(cmd, args, [env: env, stderr_to_stdout: true] ++ Keyword.drop(opts, [:env]))

    IO.write(output)

    if status != 0 do
      Mix.raise("`#{cmd} #{Enum.join(args, " ")}` exited with #{status}")
    end
  end

  defp write_bin_server(package_dir) do
    path = Path.join([package_dir, "bin", "server"])

    File.write!(path, """
    #!/bin/sh
    set -e
    cd "$(dirname "$0")/.."
    PHX_SERVER=true exec bin/manto start
    """)

    File.chmod!(path, 0o755)
  end

  defp write_readme(package_dir, version) do
    File.write!(Path.join(package_dir, "README.txt"), """
    Manto #{version}

    Manto is a local-first Markdown CMS. This package is a self-contained
    release — you don't need Elixir installed.

    Quickstart
    ----------
    1. Extract the archive:  tar -xzf manto-v#{version}.tar.gz
    2. Start the server:     cd manto-v#{version} && ./bin/server
    3. Open http://localhost:4000  (editor at /editor)

    The first time you run it, an empty vault is seeded with welcome.md.

    Settings
    --------
    The settings page (http://localhost:4000) lets you point Manto at any
    folder to use as your vault and set your site's title, description and
    base URL. They are saved to manto.json next to where you run the server.

    Optional environment variables:
      PORT             HTTP port (default 4000)
      PHX_HOST         hostname used in generated URLs (default localhost)
      SECRET_KEY_BASE  stable cookie/session key (Manto works fine without it)
    """)
  end

  defp format_size(bytes) when bytes >= 1024 * 1024,
    do: "#{Float.round(bytes / (1024 * 1024), 1)} MB"

  defp format_size(bytes) when bytes >= 1024,
    do: "#{Float.round(bytes / 1024, 1)} KB"

  defp format_size(bytes), do: "#{bytes} B"
end
