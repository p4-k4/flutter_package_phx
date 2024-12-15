defmodule PhoenixTodoWeb.Router do
  use PhoenixTodoWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {PhoenixTodoWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", PhoenixTodoWeb do
    pipe_through :browser

    live "/", TodoLive
  end

  # Enable LiveDashboard in development
  if Application.compile_env(:phoenix_todo, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: PhoenixTodoWeb.Telemetry
    end
  end
end
