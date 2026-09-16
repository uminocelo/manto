defmodule MantoWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use MantoWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders the app header (breadcrumb navigation and theme toggle) plus its
  content slot.

  This lives inside each LiveView's own template (rather than the root
  layout) so it re-renders — and `current_path` stays accurate — across live
  navigation between LiveViews. The root layout is only rendered on the
  initial static request, so anything placed there would go stale after the
  first live navigate.

  ## Examples

      <Layouts.app current_path={@current_path}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :current_path, :string, required: true

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <header class="p-4 flex items-center justify-between border-1 border-b-gray-200 border-r-transparent border-l-transparent border-t-transparent">
      <nav
        aria-label="Breadcrumb"
        class="flex items-center gap-3 text-sm text-gray-500 dark:text-gray-400"
      >
        <.link
          navigate="/"
          class={
            if @current_path == "/",
              do: "font-medium text-gray-900 dark:text-gray-100 pointer-events-none",
              else: "hover:text-gray-700 dark:hover:text-gray-200"
          }
        >
          Home
        </.link>
        <%= if String.starts_with?(@current_path, "/editor") do %>
          <span aria-hidden="true">/</span>
          <.link
            navigate="/editor"
            class={
              if @current_path == "/editor",
                do: "font-medium text-gray-900 dark:text-gray-100 pointer-events-none",
                else: "hover:text-gray-700 dark:hover:text-gray-200"
            }
          >
            Editor
          </.link>
        <% end %>
      </nav>
      <.theme_toggle />
    </header>

    {render_slot(@inner_block)}
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme-preference=light]_&]:left-1/3 [[data-theme-preference=dark]_&]:left-2/3 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
