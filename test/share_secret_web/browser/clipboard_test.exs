defmodule ShareSecretWeb.Browser.ClipboardTest do
  use PhoenixTest.Playwright.Case, async: false
  use ShareSecretWeb, :verified_routes

  alias PlaywrightEx.Frame

  @timeout Application.compile_env(:phoenix_test, [:playwright, :timeout], 5_000)

  @moduletag :playwright

  test "copies generated links and revealed secrets", %{conn: conn} do
    secret_text = "This is my super secret message!"

    session =
      conn
      |> visit(~p"/")
      |> fill_in("Enter your secret", with: secret_text)
      |> click_button("Generate links")
      |> assert_has("#copy-link-0")

    secret_link = element_value(session, "#link-0")

    session
    |> install_clipboard_mock()
    |> set_copy_duration("#copy-link-0", 2_000)
    |> click("#copy-link-0")
    |> assert_has("#copy-link-0-active")

    assert copied_text(session) == secret_link
    assert {:ok, _} = wait_for_copy_reset(session, "#copy-link-0")
    assert_has(session, "#copy-link-0-idle")

    session =
      conn
      |> visit(secret_link)
      |> click_button("Reveal")
      |> assert_has("#copy-secret")

    session
    |> install_clipboard_mock()
    |> click("#copy-secret")
    |> assert_has("#copy-secret-active")

    assert copied_text(session) == secret_text
  end

  defp install_clipboard_mock(session) do
    {:ok, _} =
      Frame.evaluate(session.frame_id,
        expression: """
        () => {
          window.copiedText = null
          Object.defineProperty(navigator, "clipboard", {
            configurable: true,
            value: {
              writeText: async text => { window.copiedText = text }
            }
          })
        }
        """,
        is_function: true,
        timeout: @timeout
      )

    session
  end

  defp set_copy_duration(session, selector, duration) do
    {:ok, _} =
      Frame.evaluate(session.frame_id,
        expression:
          "([selector, duration]) => { document.querySelector(selector).dataset.copyDuration = duration }",
        is_function: true,
        arg: [selector, duration],
        timeout: @timeout
      )

    session
  end

  defp copied_text(session) do
    {:ok, text} =
      Frame.evaluate(session.frame_id,
        expression: "() => window.copiedText",
        is_function: true,
        timeout: @timeout
      )

    text
  end

  defp element_value(session, selector) do
    {:ok, value} =
      Frame.evaluate(session.frame_id,
        expression: "selector => document.querySelector(selector).value",
        is_function: true,
        arg: selector,
        timeout: @timeout
      )

    value
  end

  defp wait_for_copy_reset(session, selector) do
    Frame.wait_for_function(session.frame_id,
      expression: "selector => !document.querySelector(selector).disabled",
      is_function: true,
      arg: selector,
      timeout: @timeout
    )
  end
end
