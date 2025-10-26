Ecto.Adapters.SQL.Sandbox.mode(ShareSecret.Repo, :manual)

Mox.defmock(ShareSecret.CryptoMock, for: ShareSecret.CryptoBehaviour)

Application.put_env(:share_secret, :crypto, ShareSecret.CryptoMock)
Application.put_env(:phoenix_test, :base_url, ShareSecretWeb.Endpoint.url())

ExUnit.start()
