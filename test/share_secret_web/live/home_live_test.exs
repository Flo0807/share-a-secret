defmodule ShareSecretWeb.HomeLiveTest do
  use ShareSecretWeb.ConnCase, async: false

  import Mox
  import Phoenix.LiveViewTest

  alias ShareSecret.Repo
  alias ShareSecret.Secrets
  alias ShareSecret.Secrets.Secret

  setup :verify_on_exit!

  test "secret pages use restrictive browser and cache headers", %{conn: conn} do
    conn = get(conn, ~p"/")

    assert ["no-store"] = get_resp_header(conn, "cache-control")
    assert ["no-referrer"] = get_resp_header(conn, "referrer-policy")
    assert [csp] = get_resp_header(conn, "content-security-policy")
    assert csp =~ "script-src 'self'"
    assert csp =~ "object-src 'none'"
    assert csp =~ "frame-ancestors 'none'"
  end

  test "creation UI is fail-closed and never submits the plaintext form", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#create-secret-root[phx-hook='SecretCreate'][phx-update='ignore']")
    assert has_element?(view, "#create-secret-form:not([phx-submit]):not([phx-change])")
    assert has_element?(view, "#secret-input[disabled]")
    assert has_element?(view, "#create-secret-submit[type='button'][disabled]")
    assert has_element?(view, "#generated-links-panel[hidden]")
  end

  test "creation accepts only exact opaque entries and does not render them", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")
    entry = encrypted_entry()

    render_hook(view, "create-encrypted-secrets", %{
      "entries" => [entry],
      "expiration" => 3600
    })

    assert_reply(view, %{ok: true})
    stored = Repo.get!(Secret, entry["id"])
    assert stored.secret == nil
    assert stored.encrypted_payload == decode!(entry["payload"])
    refute render(view) =~ entry["payload"]

    render_hook(view, "create-encrypted-secrets", %{
      "entries" => [Map.put(encrypted_entry(), "root", "must-not-cross-server")],
      "expiration" => 3600
    })

    assert_reply(view, %{ok: false, reason: "invalid_request"})
  end

  test "client reveal replies with ciphertext only and consumes exactly once", %{conn: conn} do
    claim_key = :crypto.strong_rand_bytes(32)
    entry = encrypted_entry(claim_key)
    payload = entry["payload"]
    assert {:ok, [id]} = Secrets.create_encrypted_secrets([entry], 3600)
    {:ok, view, _html} = live(conn, ~p"/#{id}")

    assert has_element?(view, "#reveal-secret-root[phx-hook='SecretReveal'][phx-update='ignore']")
    assert has_element?(view, "#reveal-secret-notice[hidden]")
    assert has_element?(view, "#reveal-secret-error[hidden]")
    assert has_element?(view, "#reveal-secret-button[disabled]")
    assert has_element?(view, "#secret-output[hidden] #secret-text:empty")

    render_hook(view, "claim-encrypted-secret", %{"claim_key" => encode(claim_key)})
    assert_reply(view, %{ok: true, version: 1, payload: ^payload})
    assert Repo.get(Secret, id) == nil

    render_hook(view, "claim-encrypted-secret", %{"claim_key" => encode(claim_key)})
    assert_reply(view, %{ok: false, reason: "invalid_link"})
  end

  test "a wrong claim does not consume the secret", %{conn: conn} do
    claim_key = :crypto.strong_rand_bytes(32)
    entry = encrypted_entry(claim_key)
    assert {:ok, [id]} = Secrets.create_encrypted_secrets([entry], 3600)
    {:ok, view, _html} = live(conn, ~p"/#{id}")

    render_hook(view, "claim-encrypted-secret", %{
      "claim_key" => encode(:crypto.strong_rand_bytes(32))
    })

    assert_reply(view, %{ok: false, reason: "invalid_link"})
    assert Repo.get(Secret, id)
  end

  test "a query parameter cannot force a v1 secret into legacy mode", %{conn: conn} do
    entry = encrypted_entry()
    assert {:ok, [id]} = Secrets.create_encrypted_secrets([entry], 3600)

    {:ok, view, _html} = live(conn, ~p"/#{id}?key=attacker-added")

    assert has_element?(view, "#reveal-secret-root")
    refute has_element?(view, "#reveal-legacy-secret-button")
  end

  test "legacy query-key links remain revealable during migration", %{conn: conn} do
    secret =
      Repo.insert!(%Secret{
        secret: "legacy ciphertext",
        expires_at:
          DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.truncate(:second)
      })

    expect(ShareSecret.CryptoMock, :decrypt!, fn "legacy ciphertext", "legacy-key" ->
      "legacy plaintext"
    end)

    {:ok, view, _html} = live(conn, ~p"/#{secret.id}?key=legacy-key")
    assert has_element?(view, "#reveal-legacy-secret-button")

    view |> element("#reveal-legacy-secret-button") |> render_click()

    assert has_element?(view, "#secret-text")
    assert Repo.get(Secret, secret.id) == nil
  end

  defp encrypted_entry(claim_key \\ :crypto.strong_rand_bytes(32)) do
    %{
      "id" => Ecto.UUID.generate(),
      "payload" => encode(<<1, :crypto.strong_rand_bytes(29)::binary>>),
      "claim_verifier" => encode(:crypto.hash(:sha256, claim_key))
    }
  end

  defp encode(value), do: Base.url_encode64(value, padding: false)
  defp decode!(value), do: Base.url_decode64!(value, padding: false)
end
