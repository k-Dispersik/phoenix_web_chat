defmodule SlaxWeb.ChatRoomLive do
  use SlaxWeb, :live_view

  alias Slax.Accounts
  alias Slax.Accounts.User
  alias Slax.Chat
  alias Slax.Chat.{Message, Room}
  alias SlaxWeb.OnlineUsers

  defp toggle_rooms() do
    JS.toggle(to: "#rooms-toggler-chevron-down")
    |> JS.toggle(to: "#rooms-toggler-chevron-right")
    |> JS.toggle(to: "#rooms-list")
  end

  defp toggle_users() do
    JS.toggle(to: "#users-toggler-chevron-down")
    |> JS.toggle(to: "#users-toggler-chevron-right")
    |> JS.toggle(to: "#users-list")
  end

  defp format_date(%Date{} = date) do
    today = Date.utc_today()

    case Date.diff(today, date) do
      0 ->
        "Today"

      1 ->
        "Yesterday"

      _ ->
        format_str = "%A, %B %e#{ordinal(date.day)}#{if today.year != date.year, do: " %Y"}"
        Timex.format!(date, format_str, :strftime)
    end
  end

  defp ordinal(day) do
    cond do
      rem(day, 10) == 1 and day != 11 -> "st"
      rem(day, 10) == 2 and day != 12 -> "nd"
      rem(day, 10) == 3 and day != 13 -> "rd"
      true -> "th"
    end
  end

  attr :dom_id, :string, required: true
  attr :on_click, JS, required: true
  attr :text, :string, required: true


  defp toggler(assigns) do
    ~H"""
    <button id={@dom_id} phx-click={@on_click} class="flex items-center flex-grow focus:outline-none">
      <.icon id={@dom_id <> "-chevron-down"} name="hero-chevron-down" class="h-4 w-4" />
      <.icon
        id={@dom_id <> "-chevron-right"}
        name="hero-chevron-right"
        class="h-4 w-4"
        style="display:none;"
      />
      <span class="ml-2 leading-none font-medium text-sm">
        <%= @text %>
      </span>
    </button>
    """
  end

  attr :user, User, required: true
  attr :online, :boolean, default: false

  defp user(assigns) do
    ~H"""
    <.link class="flex items-center h-8 hover:bg-gray-300 text-sm pl-8 pr-3" href="#">
      <div class="flex justify-center w-4">
        <%= if @online do %>
          <span class="w-2 h-2 rounded-full bg-blue-500"></span>
        <% else %>
          <span class="w-2 h-2 rounded-full border-2 border-gray-500"></span>
        <% end %>
      </div>
      <span class="ml-2 leading-none"><%= @user.username %></span>
    </.link>
    """
  end


  attr :current_user, User, required: true
  attr :dom_id, :string, required: true
  attr :message, Message, required: true
  attr :timezone, :string, required: true
  attr :users_typing, :map, default: Map.new()
  attr :joined?, :boolean, default: false
  attr :editing_message, :boolean, default: false
  attr :editing_message_id, :integer, default: -1
  attr :unread_count, :integer, required: true

  defp message(assigns) do
   ~H"""
   <div id={@dom_id} class="group relative flex px-4 py-3">
    <button
        :if={@current_user.id == @message.user_id}
        class="absolute top-4 right-12 text-blue-500 hover:text-violet-800 cursor-pointer hidden group-hover:block"
        phx-click="edit-message"
        phx-value-id={@message.id}
        >
        <.icon name="hero-pencil-square" class="h-4 w-4" />
      </button>
    <button
        :if={@current_user.id == @message.user_id}
        class="absolute top-4 right-4 text-red-500 hover:text-red-800 cursor-pointer hidden group-hover:block"
        data-confirm="Are you sure?"
        phx-click="delete-message"
        phx-value-id={@message.id}
        >
        <.icon name="hero-trash" class="h-4 w-4" />
      </button>
     <img class="h-10 w-10 rounded flex-shrink-0" src={~p"/images/one_ring.jpg"} />
     <div class="ml-2">
       <div class="-mt-1">
         <.link class="text-sm font-semibold hover:underline">
           <span><%= @message.user.username %></span>
         </.link>
         <span :if={@timezone} class="ml-1 text-xs text-gray-500">
            <%= message_timestamp(@message, @timezone) %>
          </span>
         <p class="text-sm"><%= @message.body %></p>
       </div>
     </div>
   </div>
   """
  end

  defp edit_message(assigns) do
    ~H"""
   <div id={@dom_id} class="group relative flex px-4 py-3">
         <.link class="text-sm font-semibold hover:underline">
           <span><%= @message.user.username %></span>
         </.link>
         <span :if={@timezone} class="ml-1 text-xs text-gray-500">
            <%= message_timestamp(@message, @timezone) %>
          </span>
          <textarea class="text-sm"><%= @message.body %></textarea>
      <button
        :if={@current_user.id == @message.user_id}
        class="absolute top-4 right-12 text-blue-500 hover:text-violet-800 cursor-pointer hidden group-hover:block"
        phx-click="edit-message-confirm"
        phx-value-id={@message.id}
        >
        <.icon name="hero-check" class="h-8 w-8" />
      </button>
      <button
        :if={@current_user.id == @message.user_id}
        class="absolute top-4 right-12 text-blue-500 hover:text-violet-800 cursor-pointer hidden group-hover:block"
        phx-click="edit-message-cancel"
        phx-value-id={@message.id}
        >
        <.icon name="hero-x-mark" class="h-8 w-8" />
      </button>
   </div>
   """
  end

  attr :count, :integer, required: true

  defp unread_message_counter(assigns) do
    ~H"""
    <span
      :if={@count > 0}
      class="flex items-center justify-center bg-blue-500 rounded-full font-medium h-5 px-2 ml-auto text-xs text-white"
    >
      <%= @count %>
    </span>
    """
  end

  defp message_timestamp(message, timezone) do
    message.inserted_at
    |> Timex.Timezone.convert(timezone)
    |> Timex.format!("%-l:%M %p", :strftime)
  end

  defp users_typing(assigns) do
    ~H"""
    <%= if map_size(@users_typing) > 0 do %>
      <span class="text-green-600"> Users typing:
        <%= for {_pid, user} <- @users_typing do %>
          <%= user.email %>,
        <% end %>
      </span>
    <% else %>
      <p>Everyone is silent...</p>
    <% end %>
    """
  end

  defp room_link(assigns) do
    ~H"""
    <.link
      class={[
        "flex items-center h-8 text-sm pl-8 pr-3",
        (@active && "bg-slate-300") || "hover:bg-slate-300"]}
        patch={~p"/rooms/#{@room}"}>
      <.icon name="hero-hashtag" class="h-4 w-4" />
      <span class={["ml-2 leading-none", @active && "font-bold"]}>
        <%= @room.name %>
      </span>
      <.unread_message_counter count={@unread_count} />
    </.link>
    """
  end

  def mount(_params, _session, socket) do
    rooms = Chat.list_joined_rooms_with_unread_counts(socket.assigns.current_user)
    users = Accounts.list_users()

    timezone = get_connect_params(socket)["timezone"]

    if connected?(socket) do
      OnlineUsers.track(self(), socket.assigns.current_user)
    end

    OnlineUsers.subscribe()

    Enum.each(rooms, fn {chat, _} -> Chat.subscribe_to_room(chat) end)

    socket
    |> assign(rooms: rooms, timezone: timezone, users: users)
    |> assign(users_typing: Map.new(), editing_message_id: -1)
    |> assign(online_users: OnlineUsers.list())
    |> stream_configure(:messages,
      dom_id: fn
        %Message{id: id} -> "messages-#{id}"
        :unread_marker -> "messages-unread-marker"
        %Date{} = date -> to_string(date)
        :editing_message_id -> socket.assigns.editing_message_id
      end
    )
    |> ok()
  end

  def handle_params(params, _session, socket) do
    room =
      case Map.fetch(params, "id") do
        {:ok, id} ->
          Chat.get_room!(id)

        :error ->
          Chat.get_first_room!()
      end

      last_read_id = Chat.get_last_read_id(room, socket.assigns.current_user)

      messages = room
      |> Chat.list_messages_in_room()
      |> insert_date_dividers(socket.assigns.timezone)
      |> maybe_insert_unread_marker(last_read_id)

      Chat.update_last_read_id(room, socket.assigns.current_user)

      socket
      |> assign(
        hide_topic?: false,
        joined?: Chat.joined?(room, socket.assigns.current_user),
        page_title: "#" <> room.name,
        room: room
      )
      |> stream(:messages, messages, reset: true)
      |> assign_message_form(Chat.change_message(%Message{}))
      |> push_event("scroll_messages_to_bottom", %{})
      |> update(:rooms, fn rooms ->
        room_id = room.id

        Enum.map(rooms, fn
          {%Room{id: ^room_id} = room, _} -> {room, 0}
          other -> other
        end)
      end)
      |> noreply()
  end

  defp insert_date_dividers(messages, nil), do: messages

  defp insert_date_dividers(messages, timezone) do
    messages
    |> Enum.group_by(fn message ->
      message.inserted_at
      |> DateTime.shift_zone!(timezone)
      |> DateTime.to_date()
    end)
    |> Enum.sort_by(fn {date, _msgs} -> date end, &(Date.compare(&1, &2) != :gt))
    |> Enum.flat_map(fn {date, messages} -> [date | messages] end)
  end

  defp maybe_insert_unread_marker(messages, nil), do: messages

  defp maybe_insert_unread_marker(messages, last_read_id) do
    {read, unread} =
      Enum.split_while(messages, fn
        %Message{} = message -> message.id <= last_read_id
        _ -> true
      end)

    if unread == [] do
      read
    else
      read ++ [:unread_marker | unread]
    end
  end

  defp assign_message_form(socket, changeset) do
    assign(socket, :new_message_form, to_form(changeset))
  end

  def handle_event("toggle-topic", _params, socket) do
    # {:noreply, assign(socket, hide_topic?: !socket.assigns.hide_topic?)}
    {:noreply, update(socket, :hide_topic?, &(!&1))}
  end

  def handle_event("validate-message", %{"message" => message_params}, socket) do
    changeset = Chat.change_message(%Message{}, message_params)
    Chat.broadcast_typing(socket.assigns.room, socket.assigns.current_user)

    {:noreply, assign_message_form(socket, changeset)}
  end

  def handle_event("submit-message", %{"message" => message_params}, socket) do
    %{current_user: current_user, room: room} = socket.assigns

    if Chat.joined?(room, current_user) do
      case Chat.create_message(room, message_params, current_user) do
        {:ok, _message} ->
          assign_message_form(socket, Chat.change_message(%Message{}))

        {:error, changeset} ->
          assign_message_form(socket, changeset)
      end
    else
      socket
    end

    {:noreply, socket}
  end

  def handle_event("delete-message", %{"id" => id}, socket) do
    Chat.delete_message_by_id(id, socket.assigns.current_user)

    {:noreply, socket}
  end

  def handle_event("edit-message", %{"id" => id}, socket) do
    IO.inspect(socket.assigns.editing_message_id)
    {:noreply, assign(socket, :editing_message_id, id)}
  end

  def handle_event("join-room", _, socket) do
    current_user = socket.assigns.current_user
    Chat.join_room!(socket.assigns.room, current_user)
    Chat.subscribe_to_room(socket.assigns.room)
    socket =
      assign(socket,
        joined?: true,
        rooms: Chat.list_joined_rooms_with_unread_counts(current_user)
      )

    {:noreply, socket}
  end

  def handle_info({:new_message, message}, socket) do
    room = socket.assigns.room

    socket =
      cond do
        message.room_id == room.id ->
          Chat.update_last_read_id(room, socket.assigns.current_user)

          socket
          |> stream_insert(:messages, message)
          |> push_event("scroll_messages_to_bottom", %{})

        message.user_id != socket.assigns.current_user.id ->
          update(socket, :rooms, fn rooms ->
            Enum.map(rooms, fn
              {%Room{id: id} = room, count} when id == message.room_id -> {room, count + 1}
              other -> other
            end)
          end)

        true ->
          socket
      end

    {:noreply, socket}
  end

  def handle_info({:message_deleted, message}, socket) do
    {:noreply, stream_delete(socket, :messages, message)}
  end

  def handle_info({:user_typing, user}, socket) do
    Process.send_after(self(), :clear_writing, 2000)

    users_typing = Map.put(socket.assigns.users_typing, self(), user)
    {:noreply, assign(socket, :users_typing, users_typing)}
  end

  def handle_info(:clear_writing, socket) do
    users_typing = Map.delete(socket.assigns.users_typing, self())
    {:noreply, assign(socket, :users_typing, users_typing)}
  end

  def handle_info(%{event: "presence_diff", payload: diff}, socket) do
    online_users = OnlineUsers.update(socket.assigns.online_users, diff)

    {:noreply, assign(socket, online_users: online_users)}
  end

end
