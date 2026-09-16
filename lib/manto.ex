defmodule Manto do
  @moduledoc """
  Manto: High Availability Application Management Service.
  """

  # These attributes are evaluated at compile time.
  # Mix is available during compilation, so this safely extracts the data.
  @version Mix.Project.config()[:version]
  @codename Mix.Project.config()[:codename]

  @doc """
  Returns the standard SemVer string of the application.
  """
  def version, do: @version

  @doc """
  Returns the internal fabric/dye codename of the application.
  """
  def codename, do: @codename
end
