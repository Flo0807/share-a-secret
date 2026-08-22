defmodule ShareSecretWeb.Browser.ThemeChangeTest do
  use PhoenixTest.Playwright.Case, async: true
  use ShareSecretWeb, :verified_routes

  alias PlaywrightEx.Frame

  @timeout Application.compile_env(:phoenix_test, [:playwright, :timeout], 5_000)

  @moduletag :playwright

  test "theme controls apply, persist, and expose their selected state", %{conn: conn} do
    session = visit(conn, ~p"/")

    assert theme_state(session, "system") == %{
             "pressed" => "true",
             "stored" => nil,
             "theme" => nil
           }

    select_theme(session, "dark")

    assert theme_state(session, "dark") == %{
             "pressed" => "true",
             "stored" => "dark",
             "theme" => "dark"
           }

    session = reload_page(session)

    assert theme_state(session, "dark") == %{
             "pressed" => "true",
             "stored" => "dark",
             "theme" => "dark"
           }

    replace_theme_control(session, "light")
    select_theme(session, "light")

    assert theme_state(session, "light") == %{
             "pressed" => "true",
             "stored" => "light",
             "theme" => "light"
           }

    select_theme(session, "system")

    assert theme_state(session, "system") == %{
             "pressed" => "true",
             "stored" => nil,
             "theme" => nil
           }
  end

  defp select_theme(session, theme) do
    {:ok, _result} =
      Frame.evaluate(session.frame_id,
        expression: "document.querySelector('#theme-#{theme}').click()",
        timeout: @timeout
      )
  end

  defp replace_theme_control(session, theme) do
    {:ok, _result} =
      Frame.evaluate(session.frame_id,
        expression: """
        const control = document.querySelector('#theme-#{theme}')
        control.replaceWith(control.cloneNode(true))
        window.dispatchEvent(new CustomEvent('phx:page-loading-stop'))
        """,
        timeout: @timeout
      )
  end

  defp theme_state(session, theme) do
    {:ok, state} =
      Frame.evaluate(session.frame_id,
        expression: """
        ({
          theme: document.documentElement.getAttribute('data-theme'),
          stored: localStorage.getItem('theme'),
          pressed: document.querySelector('#theme-#{theme}').getAttribute('aria-pressed')
        })
        """,
        timeout: @timeout
      )

    state
  end
end
