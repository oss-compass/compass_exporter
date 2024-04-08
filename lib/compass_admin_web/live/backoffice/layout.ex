defmodule CompassAdminWeb.Live.Backoffice.Layout do
  @behaviour Backoffice.Layout

  alias CompassAdminWeb.Endpoint
  alias CompassAdminWeb.Router.Helpers, as: Routes

 def stylesheets do
    [
      Routes.static_path(Endpoint, "/backoffice/css/app.css")
    ]
  end

  def scripts do
    [
      Routes.static_path(Endpoint, "/backoffice/js/app.js")
    ]
  end

  def logo do
    Routes.static_path(Endpoint, "/images/phoenix.png")
  end

  def footer do
    [
      {:safe,~s(
          <div class="ml-3">
              <p class="text-sm font-medium text-gray-700 group-hover:text-gray-900">
                  Made with love by
                  <a class="hover:text-gray-500" href="https://github.com/edmondfrank">@edmondfrank</a>
              </p>
              <a href="https://github.com/oss-compass/compass-exporter" class="hover:text-gray-500 text-xs mt-2 font-medium text-gray-500 group-hover:text-gray-700">
                  View source
              </a>
          </div>
        )
      }
    ]
  end

  def links do
    [
      %{
        label: "Services",
        link: "/admin",
        icon: """
        <svg fill="#000000" viewBox="0 0 16 16" xmlns="http://www.w3.org/2000/svg">
            <g id="SVGRepo_bgCarrier" stroke-width="0"></g>
            <g id="SVGRepo_tracerCarrier" stroke-linecap="round" stroke-linejoin="round"></g>
            <g id="SVGRepo_iconCarrier">
                <g>
                    <path d="M2,14H5V11H2Zm9,0h3V11H11ZM2,5H5V2H2Zm9-3V5h3V2ZM6.5,5h3V2h-3Zm0,9h3V11h-3ZM11,9.5h3v-3H11Zm-4.5,0h3v-3h-3ZM2,9.5H5v-3H2Z"></path>
                </g>
            </g>
        </svg>
        """
      },
      %{
        label: "LiveDashboard",
        link: "/admin/dashboard",
        icon: """
          <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
          </svg>
        """
      },
    ]
  end
end
