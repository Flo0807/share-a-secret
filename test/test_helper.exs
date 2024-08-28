Ecto.Adapters.SQL.Sandbox.mode(ShareSecret.Repo, :manual)

Mox.defmock(ShareSecret.CryptoMock, for: ShareSecret.CryptoBehaviour)
Application.put_env(:share_secret, :crypto, ShareSecret.CryptoMock)

ExUnit.start()
