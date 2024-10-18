defmodule SlaxWeb.TransactionsStatusLive do
  use SlaxWeb, :live_view

  def mount(params, _session, socket) do
    socket
    |> assign(:response_from_acoin, params)
    |> ok()
  end
end
