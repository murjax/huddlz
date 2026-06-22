defmodule HuddlzWeb.GroupLive.New do
  @moduledoc """
  LiveView for creating a new group.
  """
  use HuddlzWeb, :live_view

  import HuddlzWeb.Components.GroupForm
  import HuddlzWeb.Components.UploadComponents

  import HuddlzWeb.HuddlLive.FormHelpers,
    only: [
      inject_group_location_param: 2,
      prepare_source_with_coordinates: 1
    ]

  alias Huddlz.Communities.Group
  alias HuddlzWeb.GroupLive.GroupFormHooks
  alias HuddlzWeb.Layouts

  on_mount {HuddlzWeb.LiveUserAuth, :live_user_required}
  on_mount {HuddlzWeb.LiveUserAuth, :app}
  on_mount {GroupFormHooks, :default}

  @impl true
  def mount(_params, _session, socket) do
    if Ash.can?({Group, :create_group}, socket.assigns.current_user) do
      form =
        AshPhoenix.Form.for_create(Group, :create_group,
          actor: socket.assigns.current_user,
          forms: [auto?: true]
        )

      {:ok,
       socket
       |> assign(:form, to_form(form))
       |> assign(:page_title, "New Group")
       |> assign(:image_error, nil)
       |> assign(:pending_image_id, nil)
       |> assign(:pending_preview_url, nil)
       |> assign(:selected_location_data, nil)
       |> assign(:upload_processing, false)
       |> allow_upload(:group_image,
         accept: ~w(.jpg .jpeg .png .webp),
         max_entries: 1,
         max_file_size: 5_000_000,
         auto_upload: true,
         progress: &GroupFormHooks.handle_upload_progress/3
       )}
    else
      {:ok,
       socket
       |> put_flash(:error, "You need to be logged in to create groups")
       |> redirect(to: ~p"/discover?#{[scope: "groups"]}")}
    end
  end

  @impl true
  def handle_event("validate", %{"form" => params}, socket) do
    form =
      socket.assigns.form.source
      |> AshPhoenix.Form.validate(params)

    {:noreply,
     socket
     |> assign(:form, to_form(form))
     |> assign(:image_error, nil)}
  end

  @impl true
  def handle_event("save", params, socket) do
    form_params = Map.get(params, "form", params)

    params_with_owner =
      form_params
      |> Map.put("owner_id", socket.assigns.current_user.id)
      |> inject_group_location_param(socket.assigns.selected_location_data)

    case socket.assigns.form.source
         |> AshPhoenix.Form.validate(params_with_owner)
         |> AshPhoenix.Form.submit(
           params: params_with_owner,
           actor: socket.assigns.current_user,
           before_submit: prepare_source_with_coordinates(socket.assigns.selected_location_data)
         ) do
      {:ok, group} ->
        GroupFormHooks.assign_pending_image_to_group(socket, group)

        {:noreply,
         socket
         |> put_flash(:info, "Group created successfully")
         |> redirect(to: ~p"/groups/#{group.slug}")}

      {:error, form} ->
        {:noreply, assign(socket, :form, to_form(form))}
    end
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
          <h1>Create a group</h1>
          <p>
            Groups are where huddlz live. Set the name, decide who can see it, and you can invite members or schedule your first huddl in a minute.
          </p>
        </div>
      </div>

      <.form for={@form} id="group-form" phx-change="validate" phx-submit="save">
        <div class="panel">
          <div class="panel-head">
            <h2>The basics</h2>
          </div>
          <div class="form-grid">
            <.input
              field={@form[:name]}
              label="Group name"
              placeholder="e.g. Phoenix Elixir Meetup"
              autocomplete="off"
              help="3–100 characters."
            />
            <div class="form-row">
              <div class="form-help">
                URL: {url(~p"/groups/#{@form[:slug].value || "..."}")}
              </div>
            </div>
            <.textarea
              field={@form[:description]}
              label="Description"
              placeholder="Tell people what your group is about, what huddlz to expect, and who should join."
              help="Up to 5,000 characters."
            />
            <.group_location_field
              field={@form[:location]}
              latitude={@selected_location_data && @selected_location_data.latitude}
              longitude={@selected_location_data && @selected_location_data.longitude}
            />
          </div>
        </div>

        <.cover_image_panel
          upload={@uploads.group_image}
          image_error={@image_error}
          show_upload_zone={is_nil(@pending_preview_url)}
        >
          <:preview :if={@pending_preview_url}>
            <div class="image-preview" phx-drop-target={@uploads.group_image.ref}>
              <div
                class="card-cover"
                style={"height:140px; background-image: url('#{@pending_preview_url}')"}
              >
              </div>
              <div class="image-preview-foot">
                <span class="muted">Image uploaded · ready to publish.</span>
                <div class="image-preview-actions">
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
        </.cover_image_panel>

        <.group_visibility_panel field={@form[:is_public]} />

        <div class="form-foot" style="border:0; margin:0">
          <.button variant={:primary} type="submit" phx-disable-with="Creating…">
            Create group
          </.button>
          <.button variant={:secondary} navigate={~p"/my-groups"}>Cancel</.button>
        </div>
      </.form>
    </Layouts.app>
    """
  end
end
