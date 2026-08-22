# Share a Secret

**Demo:** [share-a-secret.fly.dev](https://share-a-secret.fly.dev/)

Share a Secret is an open-source and self-hosted secret sharing platform.

It lets you securely share information with trusted people through a link. This can be anything - a message, a password or a piece of information you want to share discreetly.

Once you have entered a secret, you can configure how many links you need and how long the secret will be available. This generates links that you can copy and give to trusted people. Once a link has been used, it is no longer valid.

New secrets are encrypted in the browser with AES-256-GCM before they cross the network. The server stores only an authenticated ciphertext and a one-way claim verifier. A random 256-bit root stays in the URL fragment, which browsers do not include in HTTP requests. The application removes the fragment from browser history before Phoenix LiveView establishes its connection.

The server atomically deletes a ciphertext when the recipient presents the independently derived claim capability, then the browser decrypts it. Existing links created by older releases remain temporarily compatible with the legacy server-side encryption format.

Client-side encryption protects plaintext from the application server, database, caches, and ordinary request logging. It cannot protect against compromised JavaScript served by the host, malicious browser extensions, compromised sender or recipient devices, or disclosure through browser history, clipboard contents, or link sharing. See [the encryption protocol and threat model](docs/client-encryption.md) for the complete design and operational requirements.

Tech stack:

- Elixir, Phoenix, LiveView, TailwindCSS, daisyUI, PostgreSQL

The idea for this project came from https://github.com/Luzifer/ots. I wanted to build something similar using Elixir and Phoenix. If you want to be able to share files as well, check out the linked project.

## Self-Hosted
 
In order to add an extra layer of security, you should host this application yourself. This way you can be sure that the secrets are only stored on your server and not on a third-party server. 
To keep it simple, we provide a [Docker image](https://github.com/Flo0807/share-a-secret/pkgs/container/share-a-secret) you can use to run the application.

You can use the following tags:
- `latest`: The latest stable version of the application
- `<version>`: A specific version of the application (see [releases](https://github.com/Flo0807/share-a-secret/releases) for all released versions)
- `main`: The latest version of the `main` branch

### Docker Compose

The easiest way to run the application is using Docker Compose. You can use the `compose.example.yml` file to get started.

First you have to create a secret key for the application:
  
```bash
mix phx.gen.secret
```

Copy the output and paste it into the `SECRET_KEY_BASE` environment variable in the `compose.yml` file.

Adjust the other environment variables as needed.

Then you can start the application with:

```bash
docker compose up
```

The first time you start, you will need to run the database migrations before you can use the application. Optionally, if you are not using the default database from your database container, you will also need to create the database.

The following commands need to be run inside the running container. You can do this for example with `docker compose run app <command>` or by entering the container.

Create the database:

```bash
/app/bin/create
```

Run the migrations:

```bash
/app/bin/migrate
```

You can now access the application at configured host and port. We recommend using a reverse proxy like nginx to add SSL encryption.

## Development

Setup and run PostgreSQL database, e.g. with Docker:

```bash
docker run --name postgres -e POSTGRES_PASSWORD=postgres -p 5432:5432 -d postgres
```

Configure credentials in `config/dev.exs`.

Run `mix setup` to install and setup dependencies and database.

Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`.

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.
