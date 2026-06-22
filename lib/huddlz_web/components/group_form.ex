defmodule HuddlzWeb.Components.GroupForm do
  @moduledoc """
  Presentation primitives shared by the group create and edit forms.

  ```
  <.group_location_field field={@form[:location]} latitude={@lat} longitude={@lng} />
  <.group_visibility_panel field={@form[:is_public]} />
  ```
  """
  use HuddlzWeb, :html

  attr :field, Phoenix.HTML.FormField, required: true
  attr :latitude, :any, default: nil
  attr :longitude, :any, default: nil

  def group_location_field(assigns) do
    ~H"""
    <div class="form-row">
      <label class="form-label" for="group-location-input">Location</label>
      <.live_component
        module={HuddlzWeb.Live.LocationAutocomplete}
        id="group-location"
        variant={:form}
        field_name="form[location]"
        value={@field.value}
        latitude={@latitude}
        longitude={@longitude}
        placeholder="Search for a city or region..."
        types={["locality", "sublocality", "administrative_area_level_2"]}
        fetch_coordinates={true}
        show_clear={true}
      />
      <.field_errors field={@field} always_show={true} />
      <p class="form-help">
        Optional. Helps people find your group when they search nearby.
      </p>
    </div>
    """
  end

  attr :field, Phoenix.HTML.FormField, required: true

  def group_visibility_panel(assigns) do
    ~H"""
    <div class="panel">
      <div class="panel-head">
        <div>
          <h2>Visibility</h2>
          <div class="panel-sub">
            Public groups are findable in Discover. Private groups are only visible to members.
          </div>
        </div>
      </div>
      <div class="settings-list row-list pref-list">
        <div class="row">
          <div>
            <label class="row-title" for="group-is-public">Public group</label>
            <div class="row-desc">
              Anyone can find and join this group. Huddlz are visible without signing in.
            </div>
          </div>
          <label class="toggle">
            <input type="hidden" name={@field.name} value="false" />
            <input
              id="group-is-public"
              type="checkbox"
              name={@field.name}
              value="true"
              checked={Phoenix.HTML.Form.normalize_value("checkbox", @field.value)}
            />
            <span class="track"></span>
            <span class="toggle-text">
              {if Phoenix.HTML.Form.normalize_value("checkbox", @field.value),
                do: "On",
                else: "Off"}
            </span>
          </label>
        </div>
      </div>
    </div>
    """
  end
end
