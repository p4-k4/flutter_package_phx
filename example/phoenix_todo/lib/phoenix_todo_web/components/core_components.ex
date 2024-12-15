defmodule PhoenixTodoWeb.CoreComponents do
  use Phoenix.Component

  import PhoenixTodoWeb.Gettext

  attr :id, :string, default: nil
  attr :name, :string, default: nil
  attr :label, :string, default: nil
  attr :value, :any
  attr :type, :string, default: "text"
  attr :field, :any, doc: "a form field struct"
  attr :errors, :list, default: []
  attr :class, :string, default: nil
  attr :rest, :global, include: ~w(autocomplete disabled form max maxlength min minlength
                                 pattern placeholder readonly required size step)

  def input(assigns) do
    assigns =
      assigns
      |> assign_new(:name, fn ->
        if assigns[:field] do
          assigns.field.name
        end
      end)
      |> assign_new(:id, fn ->
        if assigns[:field] do
          assigns.field.id
        end
      end)
      |> assign_new(:value, fn ->
        if assigns[:field] do
          assigns.field.value
        end
      end)
      |> assign_new(:errors, fn ->
        if assigns[:field] do
          assigns.field.errors
        else
          []
        end
      end)

    ~H"""
    <div phx-feedback-for={@name}>
      <input
        type={@type}
        name={@name}
        id={@id}
        value={Phoenix.HTML.Form.normalize_value(@type, @value)}
        class={[
          "mt-2 block w-full rounded-lg border-gray-300 focus:border-blue-500 focus:ring-blue-500",
          @errors == [] && "border-gray-300",
          @errors != [] && "border-red-500",
          @class
        ]}
        {@rest}
      />
      <.error :for={msg <- @errors}><%= msg %></.error>
    </div>
    """
  end

  def error(assigns) do
    ~H"""
    <p class="mt-2 text-sm text-red-600">
      <%= render_slot(@inner_block) %>
    </p>
    """
  end

  attr :type, :string, default: "submit"
  attr :class, :string, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def button(assigns) do
    ~H"""
    <button
      type={@type}
      class={[
        "inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md",
        "text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2",
        "focus:ring-offset-2 focus:ring-blue-500",
        @class
      ]}
      {@rest}
    >
      <%= render_slot(@inner_block) %>
    </button>
    """
  end

  attr :flash, :map, default: %{}, doc: "the map of flash messages to display"

  def flash_group(assigns) do
    ~H"""
    <div class="fixed top-2 right-2 w-80 z-50">
      <.flash kind={:info} title="Success!" flash={@flash} />
      <.flash kind={:error} title="Error!" flash={@flash} />
    </div>
    """
  end

  attr :id, :string, default: nil
  attr :flash, :map
  attr :title, :string
  attr :kind, :atom
  attr :rest, :global
  slot :inner_block

  def flash(assigns) do
    ~H"""
    <div
      :if={msg = Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      class={[
        "p-4 rounded-md mb-2",
        @kind == :info && "bg-green-50 text-green-800",
        @kind == :error && "bg-red-50 text-red-800"
      ]}
      {@rest}
    >
      <div class="flex justify-between items-center">
        <div class="flex-1">
          <p class="text-sm font-medium">
            <%= @title %>
          </p>
          <p class="mt-1 text-sm">
            <%= msg %>
          </p>
        </div>
        <button type="button" class="ml-4" aria-label={gettext("close")}>
          ×
        </button>
      </div>
    </div>
    """
  end
end
