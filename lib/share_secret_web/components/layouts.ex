defmodule ShareSecretWeb.Layouts do
  use ShareSecretWeb, :html

  embed_templates "layouts/*"

  @doc """
  Renders the app layout.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  def app(assigns) do
    ~H"""
    <.information_modal />
    <header>
      <.navbar />
    </header>
    <main class="mx-auto max-w-7xl">
      <div class="px-6 py-8">
        {@inner_content}
      </div>
    </main>
    <footer class="mx-auto max-w-7xl pb-4 text-center">
      {gettext("powered by")} <.github_icon class="inline w-4 fill-current" />
      <.link href="https://github.com/Flo0807/share-a-secret" target="_blank" class="link">
        share-a-secret
      </.link>
      v{Application.spec(:share_secret)[:vsn]}
    </footer>
    """
  end
end
