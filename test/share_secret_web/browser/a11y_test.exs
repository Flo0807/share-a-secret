defmodule ShareSecretWeb.Browser.A11yTest do
  use PhoenixTest.Playwright.Case, async: true
  use ShareSecretWeb, :verified_routes

  alias PhoenixTest.Playwright.Frame

  test "index page has no accessibility violations", %{conn: conn} do
    conn
    |> visit(~p"/")
    |> assert_a11y()
  end

  defp assert_a11y(session) do
    Frame.evaluate(session.frame_id, A11yAudit.JS.axe_core())

    {:ok, json} = Frame.evaluate(session.frame_id, "axe.run()")

    json
    |> A11yAudit.Results.from_json()
    |> A11yAudit.Assertions.assert_no_violations()

    session
  end
end
