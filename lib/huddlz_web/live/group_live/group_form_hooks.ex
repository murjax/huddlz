defmodule HuddlzWeb.GroupLive.GroupFormHooks do
  @moduledoc """
  Shared on_mount hooks and upload helpers for the group create and edit forms.

  Attach via:

      on_mount {HuddlzWeb.GroupLive.GroupFormHooks, :default}

  Then reference the upload progress callback as:

      progress: &GroupFormHooks.handle_upload_progress/3
  """

  import Phoenix.LiveView, only: [attach_hook: 4, cancel_upload: 3]
  import Phoenix.Component, only: [assign: 3]

  import HuddlzWeb.HuddlLive.FormHelpers, only: [apply_group_location_to_form: 2]

  alias Huddlz.Communities
  alias Huddlz.Communities.GroupImage
  alias Huddlz.Storage.GroupImages
  alias HuddlzWeb.Live.Helpers.ImageUploadPipeline

  def on_mount(:default, _params, _session, socket) do
    socket =
      socket
      |> attach_hook(:group_upload_events, :handle_event, &handle_upload_event/3)
      |> attach_hook(:group_location_info, :handle_info, &handle_location_info/2)

    {:cont, socket}
  end

  def handle_upload_progress(:group_image, entry, socket) do
    if entry.done? do
      {:noreply, process_eager_upload(socket)}
    else
      {:noreply, socket}
    end
  end

  def assign_pending_image_to_group(socket, group, before_assign \\ fn _group, _user -> :ok end) do
    case socket.assigns[:pending_image_id] do
      nil ->
        :ok

      image_id ->
        before_assign.(group, socket.assigns.current_user)

        with {:ok, image} <- Ash.get(GroupImage, image_id) do
          Communities.assign_group_image_to_group(image, group.id,
            actor: socket.assigns.current_user
          )
        end
    end
  end

  def soft_delete_all_group_images(group, user) do
    case Communities.list_group_images(group.id, actor: user) do
      {:ok, images} ->
        Enum.each(images, fn image ->
          Communities.soft_delete_group_image(image, actor: user)
        end)

        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp handle_upload_event("cancel_image_upload", %{"ref" => ref}, socket) do
    {:halt, cancel_upload(socket, :group_image, ref)}
  end

  defp handle_upload_event("cancel_pending_image", _params, socket) do
    {:halt, cleanup_pending_image(socket)}
  end

  defp handle_upload_event(_event, _params, socket) do
    {:cont, socket}
  end

  defp handle_location_info({:location_selected, "group-location", payload}, socket) do
    location_data = %{
      display_text: payload.display_text,
      latitude: payload.latitude,
      longitude: payload.longitude
    }

    {:halt,
     socket
     |> assign(:selected_location_data, location_data)
     |> apply_group_location_to_form(location_data.display_text)}
  end

  defp handle_location_info({:location_cleared, "group-location"}, socket) do
    {:halt,
     socket
     |> assign(:selected_location_data, nil)
     |> apply_group_location_to_form("")}
  end

  defp handle_location_info(_msg, socket), do: {:cont, socket}

  defp process_eager_upload(socket),
    do: ImageUploadPipeline.process_eager_upload(socket, upload_config())

  defp cleanup_pending_image(socket),
    do: ImageUploadPipeline.cleanup_pending_image(socket, upload_config())

  defp upload_config do
    %{
      upload_name: :group_image,
      storage: GroupImages,
      create_pending: &create_pending_group_image/3,
      cleanup: &soft_delete_pending_group_image/2
    }
  end

  defp create_pending_group_image(socket, entry, metadata) do
    Communities.create_pending_group_image(
      %{
        filename: entry.client_name,
        content_type: entry.client_type,
        size_bytes: metadata.size_bytes,
        storage_path: metadata.storage_path,
        thumbnail_path: metadata.thumbnail_path
      },
      actor: socket.assigns.current_user
    )
  end

  defp soft_delete_pending_group_image(socket, image_id) do
    with {:ok, image} <- Ash.get(GroupImage, image_id),
         true <- is_nil(image.group_id) do
      Communities.soft_delete_group_image(image, actor: socket.assigns.current_user)
    end
  end
end
