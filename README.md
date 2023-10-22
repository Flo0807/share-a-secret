# Share a Secret

Share a Secret is an open-source secret sharing platform.

It lets you securely share information with trusted people through a link. This can be anything - a message, a password or a piece of information you want to share discreetly.

Once you have entered a secret, you can configure how many links you need and how long the secret will be available. This will generate links that you can copy and give to trusted people. 
Once they have accessed the secret, the link is no longer valid. 

The secret is stored in the database using a symmetric 128bit AES encryption. The decryption key is part of the URL, adding an extra layer of security. 
Only the person with the link can decrypt the secret, ensuring it is securely delivered to the intended recipient. This means that even if someone gains access to the secret itself, they won't be able to decrypt it without the specific key in the URL.

The URLs are not stored. This means that as long as you keep the links private, it is impossible for anyone to access the decrypted secret.

Tech stack:
- Elixir, Phoenix, LiveView, TailwindCSS, daisyUI, PostgreSQL

The idea for this project came from https://github.com/Luzifer/ots. I wanted to build something similar using Elixir and Phoenix. If you want to be able to share files as well, check out the linked project.

## Development

Setup and run PostgreSQL database, e.g. with Docker:

```bash
docker run --name postgres -e POSTGRES_PASSWORD=postgres -p 5432:5432 -d postgres
```

Configure credentials in `config/dev.exs`.

Start the Phoenix server:

  * Run `mix setup` to install and setup dependencies
  * Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.