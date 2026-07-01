defmodule CairnloopExampleWeb.CollateralWiringE2ETest do
  @moduledoc """
  Real-browser proof for Phase 52 collateral wiring.

  Source tests pin the HEEx strings; this suite proves the browser receives the
  root metadata, renders the Cairnloop logo with dimensions, and can fetch each
  copied static asset through the example app.
  """
  use PhoenixTest.Playwright.Case, async: false

  @moduletag :e2e

  @logo_selector ~s(img[alt="Cairnloop"])
  @asset_paths ~w(/images/logo.svg /favicon.ico /images/favicon.svg /images/cairnloop-og.png)

  test "root metadata and local static collateral resolve in the browser", %{conn: conn} do
    conn =
      conn
      |> visit("/")
      |> assert_has(@logo_selector)

    evaluate(
      conn,
      """
      (() => {
        const meta = (property) => document.querySelector(`meta[property="${property}"]`)?.content || "";
        const icons = Array.from(document.querySelectorAll('link[rel="icon"]'))
          .map((el) => ({href: el.getAttribute('href'), type: el.getAttribute('type') || "", sizes: el.getAttribute('sizes') || ""}));

        return {
          title: document.title,
          icons,
          ogTitle: meta("og:title"),
          ogDescription: meta("og:description"),
          ogType: meta("og:type"),
          ogImage: meta("og:image"),
          ogImageAlt: meta("og:image:alt")
        };
      })()
      """,
      fn metadata ->
        assert metadata["title"] =~ "Cairnloop",
               "expected browser title to include Cairnloop, got #{inspect(metadata["title"])}"

        assert Enum.any?(metadata["icons"], &(&1["href"] == "/favicon.ico")),
               "expected /favicon.ico icon link, got #{inspect(metadata["icons"])}"

        assert Enum.any?(
                 metadata["icons"],
                 &(&1["href"] == "/images/favicon.svg" and &1["type"] == "image/svg+xml")
               ),
               "expected /images/favicon.svg SVG icon link, got #{inspect(metadata["icons"])}"

        assert metadata["ogTitle"] == "Cairnloop"
        assert metadata["ogDescription"] == "Embedded support automation for Phoenix apps."
        assert metadata["ogType"] == "website"
        assert metadata["ogImage"] =~ "/images/cairnloop-og.png"
        assert metadata["ogImageAlt"] == "Cairnloop — Support that leaves a trail."
      end
    )

    evaluate(
      conn,
      """
      (() => {
        const logo = document.querySelector('#{@logo_selector}');
        const rect = logo.getBoundingClientRect();

        return {
          src: logo.currentSrc || logo.src,
          alt: logo.getAttribute("alt"),
          complete: logo.complete,
          width: rect.width,
          height: rect.height,
          naturalWidth: logo.naturalWidth,
          naturalHeight: logo.naturalHeight
        };
      })()
      """,
      fn logo ->
        assert logo["alt"] == "Cairnloop"
        assert logo["src"] =~ "/images/logo.svg"
        assert logo["complete"], "expected logo image to finish loading"

        assert logo["width"] > 0 and logo["height"] > 0,
               "expected rendered logo box to be nonzero, got #{logo["width"]}x#{logo["height"]}"

        assert logo["naturalWidth"] > 0 and logo["naturalHeight"] > 0,
               "expected natural logo dimensions to be nonzero, got #{logo["naturalWidth"]}x#{logo["naturalHeight"]}"
      end
    )

    conn =
      conn
      |> visit("/chat")
      |> assert_has("body .phx-connected")

    evaluate(
      conn,
      """
      Promise.all(#{Jason.encode!(@asset_paths)}.map(async (path) => {
        const response = await fetch(path, {cache: "no-store"});
        return {path, ok: response.ok, status: response.status, contentType: response.headers.get("content-type") || ""};
      }))
      """,
      fn results ->
        for result <- results do
          assert result["ok"],
                 "expected #{result["path"]} to fetch successfully, got HTTP #{result["status"]}"
        end
      end
    )
  end
end
