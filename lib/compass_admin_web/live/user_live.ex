defmodule CompassAdminWeb.UserLive do
  use Backoffice.Resource.Index,
    resolver: Backoffice.Resolvers.Ecto,
    resolver_opts: [
      repo: CompassAdmin.Repo,
      # Use preload and order_by
      preload: [:login_binds],
      order_by: :id
    ],
    resource: CompassAdmin.User

  index do
    field :id
    field :role_level
    field :anonymous, :boolean
    field :email, :string
    field :name, :string
  end
end
