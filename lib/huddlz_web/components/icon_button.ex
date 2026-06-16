defmodule HuddlzWeb.Components.IconButton do
  @moduledoc """
  A compact icon-only button for inline destructive or dismissal actions.

  Tones:

    * `"muted"` — subtle; hovers to text colour (default)
    * `"danger"` — red; for destructive actions like remove/delete
  """
  use Phoenix.Component

  import HuddlzWeb.Components.Icon

  attr :name, :string, required: true
  attr :tone, :string, values: ["muted", "danger"], default: "muted"
  attr :type, :string, default: "button"
  attr :class, :any, default: nil
  attr :rest, :global

  def icon_button(assigns) do
    ~H"""
    <button type={@type} class={["icon-btn", @tone == "danger" && "danger", @class]} {@rest}>
      <.icon name={@name} />
    </button>
    """
  end
end
