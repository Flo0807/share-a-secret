# Share a Secret

**Demo:** [share-a-secret.fly.dev](https://share-a-secret.fly.dev/)

Share a Secret is an open-source and self-hosted secret sharing platform.

It lets you securely share information with trusted people through a link. This can be anything - a message, a password or a piece of information you want to share discreetly.

Once you have entered a secret, you can configure how many links you need and how long the secret will be available. This will generate links that you can copy and give to trusted people. 
Once they have accessed the secret, the link is no longer valid. 

The secret is stored in the database using a symmetric 128bit AES encryption. The decryption key is part of the URL, adding an extra layer of security. 
Only the person with the link can decrypt the secret, ensuring it is securely delivered to the intended recipient. This means that even if someone gains access to the secret itself, they won't be able to decrypt it without the specific key in the URL.

The URLs are not stored. This means that as long as you keep the links private, it is impossible for anyone to access the decrypted secret.

Tech stack:
- Elixir, Phoenix, LiveView, TailwindCSS, daisyUI, PostgreSQL

The idea for this project came from https://github.com/Luzifer/ots. I wanted to build something similar using Elixir and Phoenix. If you want to be able to share files as well, check out the linked project.

## Self-Hosted
 
In order to add an extra layer of security, you should host this application yourself. This way you can be sure that the secrets are only stored on your server and not on a third-party server. 
To keep it simple, we provide a [Docker image](https://hub.docker.com/r/florian087/share-a-secret) you can use to run the application.

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

The following commands need to be run inside the running container. You can do this for example with `docker compose run app <command>`.

Create the database:

```bash
bin/share_secret eval 'ShareSecret.Release.create()'
```

Run the migrations:

```bash
bin/share_secret eval 'ShareSecret.Release.migrate()'
```

You can now access the application at configured host and port.

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