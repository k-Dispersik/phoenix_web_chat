defmodule SlaxWeb.PageLive do
  use SlaxWeb, :live_view

  on_mount {SlaxWeb.UserAuth, :ensure_authenticated}

end
