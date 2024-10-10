defmodule Slax.Chat do
  alias Slax.Chat.Room
  alias Slax.Chat.{Message, Reaction, Reply, Room, RoomMembership}
  alias Slax.Repo
  alias Slax.Accounts.User

  import Ecto.Query
  import Ecto.Changeset

  @pubsub Slax.PubSub

  def add_reaction(emoji, %Message{} = message, %User{} = user) do
    with {:ok, reaction} <-
      %Reaction{message_id: message.id, user_id: user.id}
      |> Reaction.changeset(%{emoji: emoji})
      |> Repo.insert() do
      Phoenix.PubSub.broadcast!(@pubsub, topic(message.room_id), {:added_reaction, reaction})

      {:ok, reaction}
    end
  end

  def search_rooms(search_term) do
    from(r in Room,
      where: ilike(r.name, ^"%#{search_term}%"),
      order_by: r.name
    )
    |> Repo.all()
    |> Enum.map(&{&1, false})
  end

  def remove_reaction(emoji, %Message{} = message, %User{} = user) do
    with %Reaction{} = reaction <-
           Repo.one(
             from(r in Reaction,
               where: r.message_id == ^message.id and r.user_id == ^user.id and r.emoji == ^emoji
             )
           ),
         {:ok, reaction} <- Repo.delete(reaction) do
      Phoenix.PubSub.broadcast!(@pubsub, topic(message.room_id), {:removed_reaction, reaction})

      {:ok, reaction}
    end
  end

  def subscribe_to_room(room) do
    Phoenix.PubSub.subscribe(@pubsub, topic(room.id))
  end

  def unsubscribe_from_room(room) do
    Phoenix.PubSub.unsubscribe(@pubsub, topic(room.id))
  end

  defp topic(room_id), do: "chat_room:#{room_id}"

  def get_first_room! do
    Repo.one!(from r in Room, limit: 1, order_by: [asc: :name])
  end

  def get_room!(id) do
    Repo.get!(Room, id)
  end

  def list_rooms do
    Repo.all(from r in Room, order_by: [asc: :name])
  end

  def change_room(room, attrs \\ %{}) do
    Room.changeset(room, attrs)
  end


  def create_room(attrs) do
    %Room{}
    |> Room.changeset(attrs)
    |> Repo.insert()
  end

  def update_room(%Room{} = room, attrs) do
    room
    |> Room.changeset(attrs)
    |> Repo.update()
  end

  def list_messages_in_room(%Room{id: room_id}, opts \\ []) do
    Message
    |> where([m], m.room_id == ^room_id)
    |> order_by([m], desc: :inserted_at, desc: :id)
    |> preload_message_user_and_replies()
    |> preload_reactions()
    |> Repo.paginate(
      after: opts[:after],
      limit: 30,
      cursor_fields: [inserted_at: :desc, id: :desc]
    )
  end

  defp preload_reactions(message_query) do
    reactions_query = from r in Reaction, order_by: [asc: :id]

    preload(message_query, reactions: ^reactions_query)
  end

  defp preload_message_user_and_replies(message_query) do
    replies_query = from r in Reply, order_by: [asc: :inserted_at, asc: :id]

    preload(message_query, [:user, replies: ^{replies_query, [:user]}])
  end


  def get_message!(id) do

    Message
    |> where([m], m.id == ^id)
    |> preload_message_user_and_replies()
    |> preload_reactions()
    |> Repo.one!()
  end

  def change_message(message, attrs \\ %{}) do
    Message.changeset(message, attrs)
  end

  def update_message(%Message{} = message, attrs) do
    message
    |> change_message(attrs)
    |> Repo.update()
  end

  def create_message(room, attrs, user) do
    with {:ok, message} <-
      %Message{room: room, user: user, replies: [], reactions: []}
      |> Message.changeset(attrs)
      |> Repo.insert() do
      Phoenix.PubSub.broadcast!(@pubsub, topic(room.id), {:new_message, message})
      {:ok, message}
    end
  end

  def delete_message_by_id(id, %User{id: user_id}) do
    message = %Message{user_id: ^user_id} = Repo.get(Message, id)

    Repo.delete(message)
    Phoenix.PubSub.broadcast!(@pubsub, topic(message.room_id), {:message_deleted, message})
  end

  def broadcast_typing(room, user) do
    Phoenix.PubSub.broadcast!(@pubsub, topic(room.id), {:user_typing, user})
  end

  def join_room!(room, user) do
    Repo.insert!(%RoomMembership{room: room, user: user})
  end

  @room_page_size 10

  def list_rooms_with_joined(page, %User{} = user) do
    offset = (page - 1) * @room_page_size

    query =
      from r in Room,
        left_join: m in RoomMembership,
        on: r.id == m.room_id and m.user_id == ^user.id,
        select: {r, not is_nil(m.id)},
        order_by: [asc: :name],
        limit: ^@room_page_size,
        offset: ^offset

    Repo.all(query)
  end

  def count_room_pages do
    ceil(Repo.aggregate(Room, :count) / @room_page_size)
  end

  def joined?(%Room{} = room, %User{} = user) do
    Repo.exists?(
      from rm in RoomMembership, where: rm.room_id == ^room.id and rm.user_id == ^user.id
    )
  end


  def list_joined_rooms_with_unread_counts(%User{} = user) do
    from(room in Room,
      join: membership in assoc(room, :memberships),
      where: membership.user_id == ^user.id,
      left_join: message in assoc(room, :messages),
      on: message.id > membership.last_read_id,
      group_by: room.id,
      select: {room, count(message.id)},
      order_by: [asc: room.name]
    )
    |> Repo.all()
  end

  def list_all_rooms_with_unread_counts(%User{} = user) do
    from(room in Room,
      left_join: membership in assoc(room, :memberships),
      on: membership.user_id == ^user.id,  # Левое соединение по пользователю
      left_join: message in assoc(room, :messages),
      on: message.id > coalesce(membership.last_read_id, 0),  # Сообщения после последнего прочитанного
      group_by: room.id,
      select: {room, count(message.id)},
      order_by: [asc: room.name]
    )
    |> Repo.all()
  end

  def toggle_room_membership(room, user) do
    case  get_membership(room, user) do
      %RoomMembership{} = membership ->
        Repo.delete(membership)
        {room, false}

      nil ->
        join_room!(room, user)
        {room, true}
    end
  end

  defp get_membership(room, user) do
    Repo.get_by(RoomMembership, room_id: room.id, user_id: user.id)
  end

  def update_last_read_id(room, user) do
    case get_membership(room, user) do
      %RoomMembership{} = membership ->
        id =
          from(m in Message, where: m.room_id == ^room.id, select: max(m.id))
          |> Repo.one()

        membership
        |> change(%{last_read_id: id})
        |> Repo.update()

      nil ->
        nil
    end
  end

  def get_last_read_id(%Room{} = room, user) do
    case get_membership(room, user) do
      %RoomMembership{} = membership ->
        membership.last_read_id

      nil ->
        nil
    end
  end

  def delete_reply_by_id(id, %User{id: user_id}) do
    with %Reply{} = reply <-
           from(r in Reply, where: r.id == ^id and r.user_id == ^user_id)
           |> Repo.one() do
      Repo.delete(reply)

      message = get_message!(reply.message_id)

      Phoenix.PubSub.broadcast!(@pubsub, topic(message.room_id), {:deleted_reply, message})
    end
  end

  def change_reply(reply, attrs \\ %{}) do
    Reply.changeset(reply, attrs)
  end

  def create_reply(%Message{} = message, attrs, user) do
    with {:ok, reply} <-
      %Reply{message: message, user: user}
      |> Reply.changeset(attrs)
      |> Repo.insert() do

      message = get_message!(reply.message_id)

      Phoenix.PubSub.broadcast!(@pubsub, topic(message.room_id), {:new_reply, message})

      {:ok, reply}
      end
  end

end
