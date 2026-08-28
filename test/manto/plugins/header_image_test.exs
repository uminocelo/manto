defmodule Manto.Plugins.HeaderImageTest do
  use ExUnit.Case, async: true
  alias Manto.Plugins.HeaderImage

  test "injects banner when header_image metadata is present" do
    html = "<h1>My Page</h1>\n<p>Content here.</p>"
    metadata = %{"header_image" => "/images/hero.png"}

    result = HeaderImage.transform_html(html, metadata)

    assert result =~ ~s(class="header-image-banner")
    assert result =~ ~s(src="/images/hero.png")
    assert result =~ ~s(alt="header image")
    assert result =~ ~s(max-width:100%)
  end

  test "no injection when header_image is absent" do
    html = "<h1>My Page</h1>\n<p>Content here.</p>"

    result = HeaderImage.transform_html(html, %{})

    assert result == html
  end

  test "no injection when header_image is empty string" do
    html = "<h1>My Page</h1>\n<p>Content here.</p>"

    result = HeaderImage.transform_html(html, %{"header_image" => ""})

    assert result == html
  end

  test "injection places banner before first h1" do
    html = "<p>Intro</p>\n<h1>Title</h1>\n<p>Body</p>"
    metadata = %{"header_image" => "/banner.jpg"}

    result = HeaderImage.transform_html(html, metadata)

    {banner_idx, _} = :binary.match(result, "header-image-banner")
    {h1_idx, _} = :binary.match(result, "<h1>Title</h1>")

    assert banner_idx < h1_idx
  end

  test "banner placed at top when no h1 exists" do
    html = "<p>Just content</p>"
    metadata = %{"header_image" => "/top.png"}

    result = HeaderImage.transform_html(html, metadata)

    assert String.starts_with?(result, ~s(<div class="header-image-banner" style="max-width:100%;">))
  end

  test "rewrites relative image paths to /vault-images/" do
    html = "<h1>Page</h1>"
    metadata = %{"header_image" => "hero.jpg"}

    result = HeaderImage.transform_html(html, metadata)

    assert result =~ ~s(src="/vault-images/hero.jpg")
  end

  test "preserves absolute URLs unchanged" do
    html = "<h1>Page</h1>"

    for url <- ["https://example.com/img.png", "http://cdn.com/photo.jpg"] do
      result = HeaderImage.transform_html(html, %{"header_image" => url})
      assert result =~ ~s(src="#{url}")
    end
  end
end
