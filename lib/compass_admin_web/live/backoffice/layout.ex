defmodule CompassAdminWeb.Live.Backoffice.Layout do
  @behaviour Backoffice.Layout

  alias CompassAdminWeb.Endpoint
  alias CompassAdminWeb.Router.Helpers, as: Routes

  import CompassAdminWeb.View.IconsHelpers

  def stylesheets do
    [
      Routes.static_path(Endpoint, "/admin/assets/app.css")
    ]
  end

  def scripts do
    [
      Routes.static_path(Endpoint, "/admin/assets/app.js")
    ]
  end

  def title do
    "OSS Compass Admin"
  end

  def logo do
    "/images/og.png"
  end

  def static_path do
    "/backoffice"
  end

  def footer do
    [
      {:safe, ~s(
          <div class="ml-3">
              <p class="text-sm font-medium text-gray-700 group-hover:text-gray-900">
                  Made with love by
                  <a class="hover:text-gray-500" href="https://github.com/edmondfrank">@edmondfrank</a>
              </p>
              <a href="https://github.com/oss-compass/compass-admin" class="hover:text-gray-500 text-xs mt-2 font-medium text-gray-500 group-hover:text-gray-700">
                  View source
              </a>
          </div>
        )}
    ]
  end

  def links do
    [
      %{
        label: "Services",
        link: "/admin",
        icon: menu_icon()
      },
      %{
        label: "Docker services",
        link: "/admin/dockers",
        icon: docker_icon()
      },
      %{
        label: "Configurations",
        icon: setting_icon(),
        expanded: true,
        links:
          Application.get_env(:compass_admin, :configurations, [])
          |> Enum.map(fn {key, _path} ->
            %{
              icon: edit_file_icon(),
              label: to_string(key) |> String.capitalize() |> String.replace("_", " "),
              link: "/admin/configurations/#{key}"
            }
          end)
      },
      %{
        label: "Deployments",
        icon: rocket_icon(),
        expanded: true,
        links: [
          %{
            label: "Frontend Applications",
            link: "/admin/deployments/frontend",
            icon: react_icon()
          },
          %{
            label: "Backend Applications",
            link: "/admin/deployments/backend",
            icon: ruby_icon()
          }
        ]
      },
      %{
        label: "LiveDashboard",
        link: "/admin/dashboard",
        icon: link_icon()
      },
      %{
        label: "User",
        link: "/admin/users",
        icon: user_icon()
      },
      %{
        label: "Gitee",
        icon: gitee_icon(),
        expanded: true,
        links: [
          %{
            label: "Repositories",
            link: "/admin/gitee/repos"
          },
          %{
            label: "Issues",
            link: "/admin/gitee/issues"
          }
        ]
      },
    ]
  end
end
