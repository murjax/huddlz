defmodule HuddlzWeb.GroupLive.Edit do
  @moduledoc """
  LiveView for editing an existing group's details.
  """
  use HuddlzWeb, :live_view

  import HuddlzWeb.Components.GroupForm
  import HuddlzWeb.Components.UploadComponents

  import HuddlzWeb.HuddlLive.FormHelpers,
    only: [
      inject_group_location_param: 2,
      prepare_source_with_coordinates: 1
    ]

  alias Huddlz.Storage.GroupImages
  alias HuddlzWeb.GroupLive.GroupFormHooks
  alias HuddlzWeb.Layouts

  on_mount {HuddlzWeb.LiveUserAuth, :live_user_required}
  on_mount {HuddlzWeb.LiveUserAuth, :app}
  on_mount {GroupFormHooks, :default}

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    user = socket.assigns.current_user

    with {:ok, group} <- get_group_by_slug(slug, user),
         :ok <- authorize({group, :update_details}, user) do
      {:ok, assign_edit_form(socket, group)}
    else
      {:error, :not_found} ->
        {:ok,
         handle_error(socket, :not_found,
           resource_name: "Group",
           fallback_path: ~p"/discover?#{[scope: "groups"]}"
         )}

      {:error, :not_authorized} ->
        {:ok,
         handle_error(socket, :not_authorized,
           resource_name: "group",
           action: "edit",
           resource_path: ~p"/groups/#{slug}"
         )}
    end
  end

  defp assign_edit_form(socket, group) do
    form =
      AshPhoenix.Form.for_update(group, :update_details,
        actor: socket.assigns.current_user,
        forms: [auto?: true]
      )
      |> to_form()

    socket
    |> assign(:page_title, "Edit Group")
    |> assign(:group, group)
    |> assign(:form, form)
    |> assign(:original_slug, group.slug)
    |> assign(:slug_changed, false)
    |> assign(:image_error, nil)
    |> assign(:pending_image_id, nil)
    |> assign(:pending_preview_url, nil)
    |> assign(:selected_location_data, build_initial_location_data(group))
    |> assign(:upload_processing, false)
    |> allow_upload(:group_image,
      accept: ~w(.jpg .jpeg .png .webp),
      max_entries: 1,
      max_file_size: 5_000_000,
      auto_upload: true,
      progress: &GroupFormHooks.handle_upload_progress/3
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_user={@current_user}
      sidebar_owned_groups={@sidebar_owned_groups}
      active="my-groups"
    >
      <div class="page-head">
        <div>
          <h1>Edit Group</h1>
          <p>Update group details, photo, and visibility. Changes save when you hit save.</p>
        </div>
      </div>

      <.form for={@form} id="edit-group-form" phx-change="validate" phx-submit="update_group">
        <.cover_image_panel
          upload={@uploads.group_image}
          image_error={@image_error}
          show_upload_zone={is_nil(@pending_preview_url) && !(@group.current_image_url && @uploads.group_image.entries == [])}
        >
          <:preview :if={@pending_preview_url}>
            <div class="image-preview" phx-drop-target={@uploads.group_image.ref}>
              <div class="card-cover" style={"background-image: url('#{@pending_preview_url}')"}>
              </div>
              <div class="image-preview-foot">
                <span class="muted">New image uploaded. Save to apply.</span>
                <div class="image-preview-actions">
                  <.button variant={:primary} type="submit" phx-disable-with="Saving...">
                    Save
                  </.button>
                  <label for={@uploads.group_image.ref} class="btn-secondary upload-replace">
                    Replace
                  </label>
                  <.button variant={:muted} type="button" phx-click="cancel_pending_image">
                    Remove
                  </.button>
                </div>
              </div>
            </div>
          </:preview>
          <:preview :if={!@pending_preview_url && @group.current_image_url && @uploads.group_image.entries == []}>
            <div class="image-preview" phx-drop-target={@uploads.group_image.ref}>
              <div
                class="card-cover"
                style={"background-image: url('#{GroupImages.url(@group.current_image_url)}')"}
              >
              </div>
              <div class="image-preview-foot">
                <span class="muted">Current image. Upload a new one to replace it.</span>
                <div class="image-preview-actions">
                  <label for={@uploads.group_image.ref} class="btn-secondary upload-replace">
                    Replace
                  </label>
                  <.button
                    variant={:muted}
                    type="button"
                    phx-click="remove_image"
                    data-confirm="Are you sure you want to remove this image?"
                  >
                    Remove
                  </.button>
                </div>
              </div>
            </div>
          </:preview>
        </.cover_image_panel>

        <div class="panel">
          <div class="panel-head">
            <h2>The basics</h2>
          </div>
          <div class="form-grid">
            <.input
              field={@form[:name]}
              label="Group Name"
              autocomplete="off"
            />

            <div class="form-row">
              <label class="form-label" for={@form[:slug].id}>URL Slug</label>
              <div class="slug-control">
                <span class="slug-prefix">huddlz.com/groups/</span>
                <input
                  id={@form[:slug].id}
                  type="text"
                  name={@form[:slug].name}
                  value={@form[:slug].value}
                  class="form-input"
                  pattern="[a-z0-9-]+"
                  title="Only lowercase letters, numbers, and hyphens allowed"
                />
              </div>
              <p :if={!@slug_changed} class="form-help">
                Your group is available at: {url(~p"/groups/#{@form[:slug].value || "..."}")}
              </p>
              <div :if={@slug_changed} class="slug-warn">
                <h3>Warning: URL Change</h3>
                <p>Changing the slug will break existing links to this group.</p>
                <p>Old URL: <span class="mono">{url(~p"/groups/#{@original_slug}")}</span></p>
                <p>New URL: <span class="mono">{url(~p"/groups/#{@form[:slug].value}")}</span></p>
              </div>
            </div>

            <.textarea
              field={@form[:description]}
              label="Description"
              rows="4"
            />

            <.group_location_field
              field={@form[:location]}
              latitude={@selected_location_data && @selected_location_data.latitude}
              longitude={@selected_location_data && @selected_location_data.longitude}
            />
          </div>
        </div>

        <.group_visibility_panel field={@form[:is_public]} />

        <div class="form-foot">
          <.button variant={:primary} type="submit" phx-disable-with="Saving...">
            Save Changes
          </.button>
          <.button variant={:secondary} navigate={~p"/groups/#{@original_slug}"}>
            Cancel
          </.button>
        </div>
      </.form>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("validate", %{"form" => params}, socket) do
    form =
      socket.assigns.form.source
      |> AshPhoenix.Form.validate(params)
      |> to_form()

    slug_changed = params["slug"] != socket.assigns.original_slug

    {:noreply,
     socket
     |> assign(:form, form)
     |> assign(:slug_changed, slug_changed)
     |> assign(:image_error, nil)}
  end

  @impl true
  def handle_event("remove_image", _params, socket) do
    group = socket.assigns.group
    user = socket.assigns.current_user

    case GroupFormHooks.soft_delete_all_group_images(group, user) do
      :ok ->
        {:ok, updated_group} = Ash.load(group, [:current_image_url], actor: user)

        {:noreply,
         socket
         |> put_flash(:info, "Image removed")
         |> assign(:group, updated_group)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to remove image")}
    end
  end

  @impl true
  def handle_event("update_group", %{"form" => params}, socket) do
    params = inject_group_location_param(params, socket.assigns.selected_location_data)

    case AshPhoenix.Form.submit(socket.assigns.form.source,
           params: params,
           actor: socket.assigns.current_user,
           before_submit: prepare_source_with_coordinates(socket.assigns.selected_location_data)
         ) do
      {:ok, updated_group} ->
        GroupFormHooks.assign_pending_image_to_group(
          socket,
          updated_group,
          &GroupFormHooks.soft_delete_all_group_images/2
        )

        {:noreply,
         socket
         |> put_flash(:info, "Group updated successfully")
         |> redirect(to: ~p"/groups/#{updated_group.slug}")}

      {:error, form} ->
        {:noreply, assign(socket, :form, to_form(form))}
    end
  end

  defp build_initial_location_data(group) do
    if group.location && group.latitude && group.longitude do
      %{
        display_text: to_string(group.location),
        latitude: group.latitude,
        longitude: group.longitude
      }
    else
      nil
    end
  end

  defp get_group_by_slug(slug, actor) do
    case Huddlz.Communities.get_by_slug(slug,
           actor: actor,
           load: [:owner, :current_image_url]
         ) do
      {:ok, nil} -> {:error, :not_found}
      {:ok, group} -> {:ok, group}
      {:error, _} -> {:error, :not_found}
    end
  end
end
