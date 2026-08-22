defmodule ShareSecretWeb.Browser.SecretFlowTest do
  use PhoenixTest.Playwright.Case, async: false
  use ShareSecretWeb, :verified_routes

  alias PlaywrightEx.BrowserContext
  alias PlaywrightEx.Frame
  alias ShareSecret.Repo
  alias ShareSecret.Secrets.Secret

  @timeout Application.compile_env(:phoenix_test, [:playwright, :timeout], 5_000)

  @moduletag :playwright

  test "encrypts in the browser, scrubs the root, and consumes the secret once", %{conn: conn} do
    secret_text = "This is my super secret message!"
    install_websocket_recorder(conn)

    session =
      conn
      |> visit(~p"/")
      |> fill_in("Enter your secret", with: secret_text)
      |> click_button("Generate links")
      |> assert_has("#generated-links-panel:not([hidden])")
      |> assert_has("#link-row-0:not([hidden])")

    secret_link = element_value(session, "#link-0")
    uri = URI.parse(secret_link)
    id = String.trim_leading(uri.path, "/")
    root = String.trim_leading(uri.fragment, "v1.")

    assert uri.query == nil
    assert String.starts_with?(uri.fragment, "v1.")
    refute_frames_contain(session, [secret_text, root])

    stored = Repo.get!(Secret, id)
    assert stored.format_version == 1
    assert stored.secret == nil
    refute stored.encrypted_payload =~ secret_text

    session =
      session
      |> visit(secret_link)
      |> assert_has("#reveal-secret-root")

    assert evaluate_js(session, "window.location.hash") == ""
    refute_frames_contain(session, [secret_text, root])

    session =
      session
      |> click_button("Reveal")
      |> assert_has("#secret-output:not([hidden])")

    assert element_value(session, "#secret-text") == secret_text
    refute_frames_contain(session, [secret_text, root])
    assert Repo.get(Secret, id) == nil

    session
    |> visit(~p"/")
    |> visit(secret_link)
    |> assert_has("#invalid-link-error")
    |> refute_has("#reveal-secret-button")
  end

  test "multiple links have independent roots and can be revealed independently", %{conn: conn} do
    secret_text = "Shared secret across multiple links"

    session =
      conn
      |> visit(~p"/")
      |> fill_in("Enter your secret", with: secret_text)
      |> fill_in("Number of links", with: "3")
      |> click_button("Generate links")
      |> assert_has("#link-row-0:not([hidden])")
      |> assert_has("#link-row-1:not([hidden])")
      |> assert_has("#link-row-2:not([hidden])")

    links = for index <- 0..2, do: element_value(session, "#link-#{index}")
    assert length(Enum.uniq(links)) == 3
    assert length(links |> Enum.map(&URI.parse(&1).fragment) |> Enum.uniq()) == 3

    for link <- links do
      session =
        session
        |> visit(link)
        |> click_button("Reveal")
        |> assert_has("#secret-output:not([hidden])")

      assert element_value(session, "#secret-text") == secret_text
    end
  end

  test "a modified fragment fails without consuming the valid link", %{conn: conn} do
    session =
      conn
      |> visit(~p"/")
      |> fill_in("Enter your secret", with: "tamper-resistant")
      |> click_button("Generate links")
      |> assert_has("#link-row-0:not([hidden])")

    valid_link = element_value(session, "#link-0")
    wrong_link = replace_last_character(valid_link)

    session
    |> visit(wrong_link)
    |> click_button("Reveal")
    |> assert_has("#reveal-secret-error:not([hidden])")

    session =
      session
      |> visit(~p"/")
      |> visit(valid_link)
      |> click_button("Reveal")
      |> assert_has("#secret-output:not([hidden])")

    assert element_value(session, "#secret-text") == "tamper-resistant"
  end

  test "native validation prevents empty or out-of-range creation", %{conn: conn} do
    session =
      conn
      |> visit(~p"/")
      |> click_button("Generate links")

    assert_has(session, "#create-secret-form:not([hidden])")
    refute_has(session, "#generated-links-panel:not([hidden])")

    session = fill_in(session, "Enter your secret", with: "test secret")

    Frame.evaluate(session.frame_id,
      expression: """
      () => {
        const input = document.querySelector('#link-count')
        input.value = 0
      }
      """,
      is_function: true,
      timeout: @timeout
    )

    session
    |> click_button("Generate links")
    |> assert_has("#create-secret-form:not([hidden])")
    |> refute_has("#generated-links-panel:not([hidden])")
  end

  test "round trips Unicode and HTML-like text as a textarea value", %{conn: conn} do
    secret_text = "🔐 Special: <script>alert('no')</script>\nGrüße & goodbye"

    session =
      conn
      |> visit(~p"/")
      |> fill_in("Enter your secret", with: secret_text)
      |> click_button("Generate links")
      |> assert_has("#link-row-0:not([hidden])")

    link = element_value(session, "#link-0")

    session =
      session
      |> visit(link)
      |> click_button("Reveal")
      |> assert_has("#secret-output:not([hidden])")

    assert element_value(session, "#secret-text") == secret_text
    refute_has(session, "script:not([src])")
  end

  defp install_websocket_recorder(conn) do
    {:ok, _} =
      BrowserContext.add_init_script(conn.context_id,
        source: """
        window.__sentWebSocketFrames = []
        const originalSend = WebSocket.prototype.send

        WebSocket.prototype.send = function (data) {
          if (typeof data === 'string') {
            window.__sentWebSocketFrames.push(data)
          } else if (data instanceof ArrayBuffer) {
            window.__sentWebSocketFrames.push(new TextDecoder().decode(data))
          } else if (ArrayBuffer.isView(data)) {
            window.__sentWebSocketFrames.push(new TextDecoder().decode(data))
          }

          return originalSend.call(this, data)
        }
        """,
        timeout: @timeout
      )

    conn
  end

  defp refute_frames_contain(session, secrets) do
    frames = evaluate_js(session, "window.__sentWebSocketFrames || []")

    for secret <- secrets do
      refute Enum.any?(frames, &String.contains?(&1, secret))
    end
  end

  defp element_value(session, selector) do
    evaluate_js(session, "document.querySelector(#{Jason.encode!(selector)}).value")
  end

  defp evaluate_js(session, expression) do
    {:ok, value} = Frame.evaluate(session.frame_id, expression: expression, timeout: @timeout)
    value
  end

  defp replace_last_character(value) do
    replacement = if String.ends_with?(value, "A"), do: "B", else: "A"
    String.slice(value, 0, byte_size(value) - 1) <> replacement
  end
end
