defmodule ShareSecretWeb.CoreComponents do
  @moduledoc """
  Provides core UI components.

  At the first glance, this module may seem daunting, but its goal is
  to provide some core building blocks in your application, such as modals,
  tables, and forms. The components are mostly markup and well documented
  with doc strings and declarative assigns. You may customize and style
  them in any way you want, based on your application growth and needs.

  The default components use Tailwind CSS, a utility-first CSS framework.
  See the [Tailwind CSS documentation](https://tailwindcss.com) to learn
  how to customize them or feel free to swap in another framework altogether.

  Icons are provided by [heroicons](https://heroicons.com). See `icon/1` for usage.
  """
  use Phoenix.Component
  use ShareSecretWeb, :verified_routes

  alias Phoenix.LiveView.JS
  import ShareSecretWeb.Gettext

  @doc """
  Renders an input with label.

  A `Phoenix.HTML.FormField` may be passed as argument,
  which is used to retrieve the input name, id, and values.
  Otherwise all attributes may be passed explicitly.

  ## Types

  This function accepts all HTML input types, considering that:

    * You may also set `type="select"` to render a `<select>` tag

    * `type="checkbox"` is used exclusively to render boolean values

    * For live file uploads, see `Phoenix.Component.live_file_input/1`

  See https://developer.mozilla.org/en-US/docs/Web/HTML/Element/input
  for more information.

  ## Examples

      <.input field={@form[:email]} type="email" />
  """
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any
  attr :class, :string, default: nil

  attr :type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file hidden month number password
               range radio search select tel text textarea time url week)

  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :checked, :boolean, doc: "the checked flag for checkbox inputs"
  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"
  attr :options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"
  attr :multiple, :boolean, default: false, doc: "the multiple flag for select inputs"

  attr :rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern placeholder readonly required rows size step)

  slot :inner_block

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  def input(%{type: "checkbox"} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn ->
        Phoenix.HTML.Form.normalize_value("checkbox", assigns[:value])
      end)

    ~H"""
    <div phx-feedback-for={@name}>
      <div class="form-control">
        <label class="label cursor-pointer">
          <span :if={@label} class="label-text">
            <%= @label %>
          </span>
          <input type="hidden" name={@name} value="false" />
          <input
            type="checkbox"
            id={@id}
            name={@name}
            value="true"
            checked={@checked}
            class={["checkbox checkbox-primary", @class]}
            {@rest}
          />
        </label>
      </div>
    </div>
    """
  end

  def input(%{type: "select"} = assigns) do
    ~H"""
    <div phx-feedback-for={@name}>
      <div class="form-control">
        <label class="label">
          <span :if={@label} class="label-text">
            <%= @label %>
          </span>
        </label>
        <select id={@id} name={@name} multiple={@multiple} class={["select select-bordered", @class]}>
          <option :if={@prompt} value=""><%= @prompt %></option>
          <%= Phoenix.HTML.Form.options_for_select(@options, @value) %>
        </select>
      </div>
    </div>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    ~H"""
    <div phx-feedback-for={@name}>
      <div class="form-control">
        <label class="label">
          <span :if={@label} class="label-text">
            <%= @label %>
          </span>
        </label>
        <textarea id={@id} name={@name} class={["textarea textarea-bordered", @class]} {@rest}><%= Phoenix.HTML.Form.normalize_value("textarea", @value) %></textarea>
      </div>
    </div>
    """
  end

  # All other inputs text, datetime-local, url, password, etc. are handled here...
  def input(assigns) do
    ~H"""
    <div phx-feedback-for={@name}>
      <div class="form-control">
        <label class="label">
          <span :if={@label} class="label-text">
            <%= @label %>
          </span>
        </label>
        <input
          type={@type}
          name={@name}
          id={@id}
          value={Phoenix.HTML.Form.normalize_value(@type, @value)}
          class={["input input-bordered", @class]}
          {@rest}
        />
      </div>
    </div>
    """
  end

  @doc """
  Renders a secret link with a copy button.
  """
  attr :id, :string, required: true, doc: "unique id for the link"
  attr :link, :string, required: true, doc: "the link"
  attr :class, :string, default: nil, doc: "extra class to be added to the link"

  def secret_link(assigns) do
    ~H"""
    <div class={["flex space-x-2", @class]}>
      <input id={@id} type="text" class="input input-bordered w-full" value={@link} />

      <div class="tooltip" data-tip={gettext("Copy")}>
        <.copy_to_clipboard
          class="btn btn-neutral"
          aria-label={gettext("Copy %{id}", %{id: @id})}
          clipboard_text={@link}
        >
          <:active>
            <.icon class="text-success" name="hero-clipboard-document-check" />
          </:active>
          <:idle>
            <.icon name="hero-clipboard" />
          </:idle>
        </.copy_to_clipboard>
      </div>
    </div>
    """
  end

  @doc """
  Renders a modal.
  """
  attr :id, :string, required: true, doc: "the unique id of the modal"
  attr :header, :string, default: nil, doc: "the modal header"

  slot :inner_block, doc: "the inner block that renders the modal content"

  def modal(assigns) do
    ~H"""
    <dialog id={@id} class="modal">
      <div class="modal-box">
        <form method="dialog">
          <button class="btn btn-sm btn-circle btn-ghost absolute top-2 right-2">✕</button>
        </form>
        <h3 if={@header} class="text-base-content text-lg font-bold">
          <%= @header %>
        </h3>
        <%= render_slot(@inner_block) %>
      </div>
      <form method="dialog" class="modal-backdrop">
        <button>
          <%= gettext("close") %>
        </button>
      </form>
    </dialog>
    """
  end

  @doc """
  Renders an alert.
  """
  attr :type, :atom, required: true, values: [:error, :info, :warning], doc: "alert type"
  attr :text, :string, required: true, doc: "text to be displayed in the alert"
  attr :class, :string, default: nil, doc: "extra class to be added to the alert"

  def alert(%{type: :error} = assigns) do
    ~H"""
    <div class={["alert alert-error", @class]}>
      <.icon name="hero-exclamation-triangle" />
      <p>
        <%= @text %>
      </p>
    </div>
    """
  end

  def alert(%{type: :info} = assigns) do
    ~H"""
    <div class={["alert alert-info", @class]}>
      <.icon name="hero-information-circle" />
      <p>
        <%= @text %>
      </p>
    </div>
    """
  end

  def alert(%{type: :warning} = assigns) do
    ~H"""
    <div class={["alert alert-warning", @class]}>
      <.icon name="hero-exclamation-triangle" />
      <p>
        <%= @text %>
      </p>
    </div>
    """
  end

  @doc """
  Renders a [Heroicon](https://heroicons.com).

  Heroicons come in three styles – outline, solid, and mini.
  By default, the outline style is used, but solid and mini may
  be applied by using the `-solid` and `-mini` suffix.

  You can customize the size and colors of the icons by setting
  width, height, and background color classes.

  Icons are extracted from your `assets/vendor/heroicons` directory and bundled
  within your compiled app.css by the plugin in your `assets/tailwind.config.js`.

  ## Examples

      <.icon name="hero-x-mark-solid" />
      <.icon name="hero-arrow-path" class="ml-1 w-3 h-3 animate-spin" />
  """
  attr :name, :string, required: true
  attr :class, :string, default: nil

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  @doc """
  Renders the github icon.
  """
  attr :class, :string, default: nil, doc: "extra class to be added to the icon"

  def github_icon(assigns) do
    ~H"""
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" class={@class}>
      <path d="M256,32C132.3,32,32,134.9,32,261.7c0,101.5,64.2,187.5,153.2,217.9a17.56,17.56,0,0,0,3.8.4c8.3,0,11.5-6.1,11.5-11.4,0-5.5-.2-19.9-.3-39.1a102.4,102.4,0,0,1-22.6,2.7c-43.1,0-52.9-33.5-52.9-33.5-10.2-26.5-24.9-33.6-24.9-33.6-19.5-13.7-.1-14.1,1.4-14.1h.1c22.5,2,34.3,23.8,34.3,23.8,11.2,19.6,26.2,25.1,39.6,25.1a63,63,0,0,0,25.6-6c2-14.8,7.8-24.9,14.2-30.7-49.7-5.8-102-25.5-102-113.5,0-25.1,8.7-45.6,23-61.6-2.3-5.8-10-29.2,2.2-60.8a18.64,18.64,0,0,1,5-.5c8.1,0,26.4,3.1,56.6,24.1a208.21,208.21,0,0,1,112.2,0c30.2-21,48.5-24.1,56.6-24.1a18.64,18.64,0,0,1,5,.5c12.2,31.6,4.5,55,2.2,60.8,14.3,16.1,23,36.6,23,61.6,0,88.2-52.4,107.6-102.3,113.3,8,7.1,15.2,21.1,15.2,42.5,0,30.7-.3,55.5-.3,63,0,5.4,3.1,11.5,11.4,11.5a19.35,19.35,0,0,0,4-.4C415.9,449.2,480,363.1,480,261.7,480,134.9,379.7,32,256,32Z">
      </path>
    </svg>
    """
  end

  @doc """
  Renders the logo icon.
  """
  attr :class, :string, default: nil, doc: "extra class to be added to the icon"

  def logo_icon(assigns) do
    ~H"""
    <svg class={@class} viewBox="137.54 138.16 762.29 770.42">
      <path d="M490 138.7c-49.5 4.9-90.9 16.8-136.5 39.3-41.8 20.6-70.8 41.3-102.5 73-38.4 38.5-65.9 79.4-85 126.5-13.6 33.6-22.1 67.3-27.2 107-1.9 15.3-1.6 62.7.5 80.3 11.3 92.7 47.9 168.8 112.1 232.7 29.7 29.6 55.7 48.2 95.9 68.6 44.2 22.4 81.4 34.2 128.2 40.5 20.5 2.8 67 2.6 87.2-.4 57.8-8.5 110.9-28.5 162.3-61.2 22.9-14.5 39.6-27.7 59.4-47 69.2-67.3 107.8-152.9 114.7-254.5 5.2-77.6-17.8-163.9-61.4-229.5-33.7-50.7-77.5-92.6-128.2-122.4-50.6-29.8-104.4-47.7-158.5-52.6-10.5-.9-52.6-1.2-61-.3zm56.5 18.1c18.5 4 37.4 12.9 48.5 22.9 3.2 2.9 6.5 5.3 7.2 5.3 5 0 33.6 10.2 52.2 18.6 73.2 33.2 135.8 92.6 171.1 162.5 20.6 40.7 31.2 75.6 36.7 120.9 1.7 13.5 1.6 55.2 0 69.5-8.7 74.8-32.4 133.2-75.7 186.5-43 53-101.4 92.7-168.7 114.9-9.2 3.1-9.8 3.4-12.3 7.7-6.2 10.5-18.5 19.5-31.1 22.8-8.7 2.3-101.9 2.4-110.3.1-12.2-3.2-24.1-11.8-30.7-22.2-3.3-5.1-3.5-5.2-13.6-8.3-14.9-4.6-29.3-10.3-45.6-18.1-38.4-18.3-69.3-39.9-98.2-68.9-55.4-55.3-85.8-115.6-98.9-195.6-10.2-62.7-1.1-130.9 25.6-192.3 22.6-51.9 63.1-102.8 109.8-137.8 36-26.9 80.8-49.8 115.5-58.9 6.8-1.8 10.3-3.3 12.5-5.3 12-11.3 36.3-21.8 59.5-25.6 11.4-1.9 34.5-1.2 46.5 1.3z" /><path d="M531 171.7c-6.3.6-15.4 3.5-23.1 7.3-7.1 3.5-16.9 8.9-16.9 9.4 0 .1 3.9-.2 8.8-.7 10.4-1 28-.2 39.3 1.8 4.5.8 8.3 1.6 8.5 1.8.2.2-7.8 1.8-17.9 3.6-42.7 7.7-65.5 14.4-86.8 25.2-12 6.1-21.1 14.5-23 21-2.3 7.6-1.7 42.7.9 58.7L423 313l-3.9 3.9c-8.4 8.4-9.5 23.8-2.8 37.3 4 8.2 12.2 16.9 20.1 21.5 4.6 2.6 5.1 3.4 8.5 11.8 6.5 16.1 16.4 31 30 44.8 21.8 22.4 43.7 27.5 67.2 15.7 19.9-10.1 43.5-40 51.6-65.4.7-2.1 2.7-4 7.4-6.8 15.7-9.4 26.3-27.6 24.4-42.3-.7-6.3-4.5-14.7-8.1-18l-2.7-2.5 1.7-10.3c3.8-23.6 4.4-52.7 1.4-63-.7-2.1-2.8-5.6-4.7-7.8l-3.6-3.9-15 3.9c-15.6 4.1-34.3 10.3-43.9 14.5-3.1 1.4-5.6 2.3-5.6 2.1 0-.2 3.9-2.8 8.8-5.8 10.8-6.8 25.1-13.9 41-20.2 6.7-2.7 12.2-5.2 12.2-5.5 0-1.7-8.2-13.1-13.4-18.7-7.8-8.4-16.5-14.8-26.1-19.3-11.4-5.4-26.3-8.3-36.5-7.3zm16.9 36.7c-.2.3-13.7 5.3-29.9 11.2-16.2 5.9-34.2 12.7-40 15.1-12.8 5.5-35.1 16.5-39.1 19.4-4.9 3.4-4.3 1.6 1.6-4.9 20.7-22.8 62.7-39.5 103.4-41 2.4-.1 4.2 0 4 .2zM600.4 316c.1 23.8-.2 30-1.7 37.4-3.6 17.6-8.5 29.9-16 40.1-2.4 3.2-2.8 3.5-2.3 1.5.4-1.4 2.6-11.7 5.1-23 7.1-33.1 11.2-60.9 12.3-83 .6-13.1.6-13.3 1.5-7.5.6 3.3 1 18.8 1.1 34.5z" /><path d="M586.6 426.5c-3.4 5.2-17.2 19.9-23.5 25.1-7.8 6.5-19.4 12.6-28.1 15-7.9 2.1-23.4 2.3-31 .5-7.8-1.9-17.2-6.3-24.3-11.5-6.2-4.4-20-18-26.9-26.5l-3.6-4.5-.6 8.5c-.3 4.6-.8 16.9-1.1 27.4l-.6 19 25.3 17c13.9 9.4 28.3 19.1 32.1 21.5 3.7 2.5 6.7 4.9 6.7 5.3 0 .8-3.6 6.1-17.9 26.1-2.7 3.9-4.7 7.5-4.4 8 .4.6 3.8 4.6 7.6 8.9l7 7.8-1.1 6.7c-.6 3.7-2.4 14-4 22.9-1.6 9-2.7 16.3-2.3 16.3.3 0 2.6-.7 5-1.6 10.4-3.6 27.7-3.6 38 .1 2.3.8 4.1 1.1 4.1.8 0-.4-1.9-10.7-4.2-23l-4.1-22.2 7.6-8.5c4.3-4.6 7.7-8.7 7.7-9 0-.4-4.4-6.6-9.8-13.9-5.4-7.3-10.7-14.6-12-16.3l-2.1-3.1 30.7-20.7c16.9-11.3 31.5-21.2 32.4-22 1.7-1.2 1.7-3.1.8-28.6-.6-15.1-1.2-27.5-1.4-27.7-.2-.2-1.1.8-2 2.2zM429.9 468.9c-.2.5-7.9 8.8-17.1 18.4-13.8 14.4-17.5 17.7-21.5 19.2-2.6 1-13.6 5.4-24.3 9.8-22.8 9.3-62 24.6-87.5 34.2-9.9 3.7-18.5 7.1-19.2 7.7-1 .8-2.5 6.5-9.3 35.3-8 33.7-16.9 75.6-18.5 86.5-.6 4.4-.3 4.9 8.2 18.2 31.1 48.6 62.9 79.9 109.5 108 21.1 12.7 57.3 29.8 72.6 34.3l2.2.6v-48.3c0-28.9.5-50.1 1.1-52.7 2.4-10.6 10.7-22.5 20.6-29.2l4.3-3v-17.1c0-19.2 1.2-26.2 6.3-36.3 3.1-6.3 7.1-12.2 9.5-14.2 1.3-1.1 1.1-2.1-1.3-7.5-11.4-26.3-23.6-67.8-29-99-3.1-18.1-4.3-30.3-4.9-49.7-.5-14.4-.9-17.7-1.7-15.2zM605.7 489.6c-.6 23.6-2.5 39.2-7.8 63.4-5 23-13.3 50.6-22 72.9l-4.8 12.4 4.4 6.2c10 13.9 12.5 23.5 12.5 47.7 0 9.3.4 16.8.9 16.8s4.3 3.2 8.5 7.1c9.5 8.9 14.1 17.5 15.7 29.4.6 4.9.9 24.8.7 51.8-.2 24-.2 43.7 0 43.7 2.1 0 31-12.6 44.8-19.6 45.3-22.9 78.3-48.4 109.4-84.9 10.6-12.3 14.5-17.6 27.5-37.1l10.3-15.3-2.3-11.8c-7.6-38.5-24.2-112.1-25.7-114-.5-.7-2.6-1.7-4.6-2.4-2-.6-7.5-2.6-12.2-4.4-4.7-1.9-21.8-8.3-38-14.3-27.8-10.4-74.8-29-79.3-31.4-1.8-.9-23.2-22.6-33.4-33.7l-4-4.5-.6 22z" /><path d="M506.4 630.5c-8.5 1.8-17.2 6.5-24.2 13-7.5 7-11.4 12.9-14.6 22.7-2.4 7.2-2.6 8.9-2.6 27.5 0 10.9-.3 20.7-.6 21.8-.3 1.2-2.3 2.8-5 3.9-6.3 2.6-13.6 10.2-17.6 18.3l-3.3 6.8-.3 50.1c-.3 49.2-.2 50.3 1.9 55.9 4.3 11.4 14.3 20.7 26.6 24.5 6.1 1.9 9.3 2 50.2 2 24 0 46.2-.4 49.4-1 13.2-2.1 24.8-10.6 30.6-22.5 3.4-6.9 4-15.1 4-57.5 0-44.4-.6-51.5-4.4-59.3-3.3-6.7-11.3-14.7-17.9-17.9l-4.6-2.2v-21.1c0-23.1-.9-28.7-5.8-37.9-3.8-7.1-16.4-19.5-23.2-22.8-11.5-5.7-25.3-7.2-38.6-4.3zm33.6 8.7c12.7 6 21.7 15.8 26.1 28.5 1.6 4.8 1.9 8.5 1.9 26.5V715h-97v-20.8c0-19.3.2-21.2 2.4-27.5 3.8-10.8 12.8-21.2 22.6-26.2 8.4-4.4 14.1-5.5 25.5-5.2 10.2.3 11.5.5 18.5 3.9zm4.7 95.7 22.1.6 4.4 3.1c2.6 1.9 5.4 5.3 7.1 8.4l2.7 5.2v43.2c0 27-.4 44.5-1.1 46.9-1.3 4.9-6.3 10.5-11.4 12.8-3.7 1.7-7.6 1.9-48.6 1.9-30.6 0-45.7-.4-48-1.1-4.3-1.5-9.5-6.3-12-11.2-1.9-3.7-2-6-1.9-48.9.1-49-.1-47.7 5.9-54.1 3.8-4.2 7.8-6 15.1-6.7 8.3-.9 37.4-1 65.7-.1z" /><path d="M508.6 650.6c-9.7 3.1-17 9.7-21.4 19.4-2.2 4.7-2.6 7.2-3 18.7l-.5 13.3H554l.2-7.8c.6-19.5-.9-25.5-8.3-33.7-6.9-7.5-14-10.7-24.4-11.2-5.3-.2-9.7.3-12.9 1.3zM515.1 760.2c-5 .8-10.4 4.6-13.2 9.2-3.7 6-2 16.6 3.6 22.2l2.7 2.7-2.7 16.6c-1.4 9.1-2.8 17.6-3.1 18.8l-.4 2.3h17c14.3 0 17-.2 17-1.5 0-.8-1.1-7.9-2.5-15.7-3.2-18.1-3.2-20.8-.1-23.7 13.6-12.8.9-34.3-18.3-30.9z" />
    </svg>
    """
  end

  @spec information_modal(any) :: Phoenix.LiveView.Rendered.t()
  @doc """
  Renders the information modal.
  """

  def information_modal(assigns) do
    ~H"""
    <.modal id="information_modal" header={gettext("How it works")}>
      <div class="bg-base-100 text-base-content space-y-2">
        <p class="mt-4">
          <span class="font-semibold">Share a Secret</span>
          <%= gettext(
            "lets you securely share information with trusted people through a link. This can be anything - a message, a password or a piece of information you want to share discreetly."
          ) %>
        </p>
        <p>
          <%= gettext(
            "Once you have entered a secret, you can configure how many links you need and how long the secret will be available. This will generate links that you can copy and give to trusted people. Once they have accessed the secret, the link is no longer valid."
          ) %>
        </p>
        <p>
          <%= gettext(
            "The secret is stored in the database in an encrypted form. The decryption key is part of the URL, adding an extra layer of security. Only the person with the link can decrypt the secret, ensuring it is securely delivered to the intended recipient. This means that even if someone gains access to the secret itself, they won't be able to decrypt it without the specific key in the URL."
          ) %>
        </p>
        <p>
          <%= gettext(
            "The URLs are not stored. This means that as long as you keep the links private, it is impossible for anyone to access the decrypted secret."
          ) %>
        </p>
      </div>
    </.modal>
    """
  end

  @doc """
  Renders the navbar.
  """

  def navbar(assigns) do
    ~H"""
    <nav class="navbar border-base-200 border-b px-2 py-2 shadow-sm">
      <div class="flex-1">
        <.link navigate={~p"/"} aria-label={gettext("Homepage")}>
          <span class="btn btn-ghost flex items-center space-x-1 normal-case">
            <.logo_icon class="inline-block h-6 w-auto fill-current" />
            <p class="hidden text-xl sm:block">Share a Secret</p>
          </span>
        </.link>
      </div>

      <div class="flex-none">
        <div class="menu menu-horizontal items-center">
          <div class="dropdown dropdown-end">
            <label tabindex="0" class="btn btn-ghost text-sm normal-case">
              <%= gettext("Theme") %> <.icon name="hero-chevron-down" class="h-4 w-4" />
            </label>
            <div
              tabindex="0"
              class="dropdown-content z-[1] menu bg-base-200 rounded-box w-32 p-2 shadow"
            >
              <button class="btn btn-sm mb-1 text-sm normal-case" data-set-theme="light">
                <.icon name="hero-sun" class="mr-1 inline-block h-4 w-4" /> <%= gettext("Light") %>
              </button>

              <button class="btn btn-sm text-sm normal-case" data-set-theme="dark">
                <.icon name="hero-moon" class="mr-1 inline-block h-4 w-4" /> <%= gettext("Dark") %>
              </button>
            </div>
          </div>

          <.link
            href="https://github.com/Flo0807/share-a-secret"
            target="_blank"
            aria-label={gettext("GitHub")}
          >
            <span class="btn btn-ghost">
              <.github_icon class="inline-block h-6 w-6 fill-current" />
            </span>
          </.link>

          <button class="btn btn-ghost" onclick="information_modal.showModal()">
            <.icon name="hero-information-circle" class="h-6 w-6" />
          </button>
        </div>
      </div>
    </nav>
    """
  end

  attr :clipboard_text, :string, required: true, doc: "the text to be copied to the clipboard"

  attr :animation_duration, :integer,
    default: 500,
    doc: "the duration of the animation in milliseconds"

  attr :class, :string, default: nil, doc: "extra class to be added to the button"

  attr :rest, :global

  slot :active, doc: "the inner block that renders the button content when it is active"
  slot :idle, doc: "the inner block that renders the button content when it is in idle"

  def copy_to_clipboard(assigns) do
    ~H"""
    <button
      x-data={"{
        copyNotification: false,
        copyToClipboard() {
            navigator.clipboard.writeText('#{@clipboard_text}');
            this.copyNotification = true;
            let that = this;
            setTimeout(function(){
                that.copyNotification = false;
            }, #{@animation_duration});
        }
      }"}
      @click="!copyNotification && copyToClipboard();"
      class={@class}
      {@rest}
    >
      <span x-show="!copyNotification">
        <%= render_slot(@idle) %>
      </span>
      <span x-show="copyNotification" x-cloak>
        <%= render_slot(@active) %>
      </span>
    </button>
    """
  end

  ## JS Commands

  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      transition:
        {"transition-all transform ease-out duration-300",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
  end

  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 200,
      transition:
        {"transition-all transform ease-in duration-200",
         "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
  end
end
