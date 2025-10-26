defmodule ShareSecretWeb.Browser.SecretFlowTest do
  use PhoenixTest.Playwright.Case, async: false
  use ShareSecretWeb, :verified_routes

  import Mox

  alias PhoenixTest.Playwright.Frame
  alias ShareSecret.CryptoMock

  @moduletag :playwright

  setup :verify_on_exit!
  setup :set_mox_global

  test "create secret, reveal it, and verify it's no longer available", %{conn: conn} do
    secret_text = "This is my super secret message!"
    encryption_key = "test_encryption_key_123"
    encrypted_secret = "encrypted_" <> secret_text

    expect(CryptoMock, :generate_key, fn -> encryption_key end)
    expect(CryptoMock, :encrypt, fn ^secret_text, ^encryption_key -> encrypted_secret end)
    expect(CryptoMock, :decrypt!, fn ^encrypted_secret, ^encryption_key -> secret_text end)

    # Step 1: Visit index page and create a secret
    session =
      conn
      |> visit(~p"/")
      |> fill_in("Enter your secret", with: secret_text)
      |> click_button("Generate links")
      |> assert_has("h1", text: "Your links")
      |> assert_has("#link-0")

    # Step 2: Extract the generated secret link
    secret_link = get_link_url(session)

    # Step 3: Navigate to the secret link
    session =
      conn
      |> visit(secret_link)
      |> assert_has("h1", text: "Reveal a secret")
      |> assert_has(".alert-info", text: "Once you have revealed the secret")

    # Step 4: Click the reveal button and verify the secret is displayed
    session
    |> click_button("Reveal")
    |> assert_has("#secret-text", text: secret_text)

    # Step 5: Navigate to the link again and verify it's no longer available
    conn
    |> visit(secret_link)
    |> assert_has(".alert-error", text: "Invalid link")
    |> assert_has(".alert-error", text: "the secret has already been revealed")
    |> refute_has("button", text: "Reveal")
  end

  test "multiple links for same secret work independently", %{conn: conn} do
    secret_text = "Shared secret across multiple links"
    encryption_key = "multi_link_key_456"
    encrypted_secret = "encrypted_" <> secret_text

    # Set up expectations for 3 links
    expect(CryptoMock, :generate_key, 3, fn -> encryption_key end)
    expect(CryptoMock, :encrypt, 3, fn ^secret_text, ^encryption_key -> encrypted_secret end)
    expect(CryptoMock, :decrypt!, 3, fn ^encrypted_secret, ^encryption_key -> secret_text end)

    # Create secret with 3 links
    session =
      conn
      |> visit(~p"/")
      |> fill_in("Enter your secret", with: secret_text)
      |> fill_in("Number of links", with: "3")
      |> click_button("Generate links")
      |> assert_has("#link-0")
      |> assert_has("#link-1")
      |> assert_has("#link-2")

    # Extract all 3 links
    link_0 = get_link_url(session, 0)
    link_1 = get_link_url(session, 1)
    link_2 = get_link_url(session, 2)

    # Verify all links are different
    assert link_0 != link_1
    assert link_1 != link_2
    assert link_0 != link_2

    # Reveal using link #0
    conn
    |> visit(link_0)
    |> click_button("Reveal")
    |> assert_has("#secret-text", text: secret_text)

    # Try link #0 again - should fail
    conn
    |> visit(link_0)
    |> assert_has(".alert-error", text: "Invalid link")
    |> refute_has("button", text: "Reveal")

    # Reveal using link #1 - should still work
    conn
    |> visit(link_1)
    |> click_button("Reveal")
    |> assert_has("#secret-text", text: secret_text)

    # Try link #1 again - should fail
    conn
    |> visit(link_1)
    |> assert_has(".alert-error", text: "Invalid link")
    |> refute_has("button", text: "Reveal")

    # Reveal using link #2 - should still work
    conn
    |> visit(link_2)
    |> click_button("Reveal")
    |> assert_has("#secret-text", text: secret_text)

    # Try link #2 again - should fail
    conn
    |> visit(link_2)
    |> assert_has(".alert-error", text: "Invalid link")
    |> refute_has("button", text: "Reveal")
  end

  test "validates secret is required", %{conn: conn} do
    # Visit homepage and try to submit without filling secret
    session =
      conn
      |> visit(~p"/")
      |> click_button("Generate links")

    # Should still be on the form page (form validation prevented submission)
    session
    |> assert_has("h1", text: "Enter your secret")
  end

  test "validates link count is within range", %{conn: conn} do
    session =
      conn
      |> visit(~p"/")
      |> fill_in("Enter your secret", with: "test secret")

    # Set value to 0 and trigger the input event to call LiveView validation
    Frame.evaluate(
      session.frame_id,
      """
      const input = document.querySelector('input[type=number]');
      input.value = 0;
      input.dispatchEvent(new Event('input', { bubbles: true }));
      input.dispatchEvent(new Event('change', { bubbles: true }));
      """
    )

    # Should show validation error
    session
    |> assert_has(".text-error", text: "must be greater than 0")
  end

  test "shows error for various invalid URLs", %{conn: conn} do
    # Test 1: Invalid UUID
    conn
    |> visit("/not-a-valid-uuid?key=somekey")
    |> assert_has(".alert-error", text: "Invalid link")
    |> refute_has("button", text: "Reveal")

    # Test 2: Valid UUID but missing key parameter
    valid_uuid = Ecto.UUID.generate()

    conn
    |> visit("/#{valid_uuid}")
    |> assert_has(".alert-error", text: "Invalid link")
    |> refute_has("button", text: "Reveal")

    # Test 3: Valid UUID but secret doesn't exist
    conn
    |> visit("/#{valid_uuid}?key=somekey")
    |> assert_has(".alert-error", text: "Invalid link")
    |> refute_has("button", text: "Reveal")
  end

  test "handles special characters in secret", %{conn: conn} do
    # Test with HTML special characters and quotes (avoiding script tags that might cause issues)
    secret_text = "Special chars: <div>Hello & goodbye</div> \"quotes\" 'apostrophes' @#$%"
    encryption_key = "special_chars_key"
    encrypted_secret = "encrypted_special"

    expect(CryptoMock, :generate_key, fn -> encryption_key end)
    expect(CryptoMock, :encrypt, fn ^secret_text, ^encryption_key -> encrypted_secret end)
    expect(CryptoMock, :decrypt!, fn ^encrypted_secret, ^encryption_key -> secret_text end)

    # Create secret with special characters
    session =
      conn
      |> visit(~p"/")
      |> fill_in("Enter your secret", with: secret_text)
      |> click_button("Generate links")
      |> assert_has("h1", text: "Your links")
      |> assert_has("#link-0")

    # Extract and visit the link
    secret_link = get_link_url(session, 0)

    # Reveal and verify the secret is displayed
    session =
      conn
      |> visit(secret_link)
      |> click_button("Reveal")
      |> assert_has("#secret-text")

    # Verify the textarea contains the key parts of our special characters
    {:ok, revealed_text} =
      Frame.evaluate(session.frame_id, "document.querySelector('#secret-text').value")

    assert revealed_text == secret_text
  end

  defp get_link_url(session, index \\ 0) do
    {:ok, link} =
      Frame.evaluate(session.frame_id, "document.querySelector('#link-#{index}').value")

    link
  end
end
