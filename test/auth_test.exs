defmodule SgiathAuthTest do
  use ExUnit.Case, async: false

  import Plug.Test

  alias SgiathAuth.Scope

  @test_user %{"id" => "user_123", "email" => "test@example.com"}
  @admin_profile %{id: "admin_1", email: "admin@example.com"}

  describe "require_admin/2 plug" do
    test "continues when user is admin" do
      scope = %Scope{user: @test_user, admin: @admin_profile}
      conn = build_conn_with_scope(scope)

      result = SgiathAuth.require_admin(conn, [])

      refute result.halted
    end

    test "redirects to / when user is not admin" do
      scope = %Scope{user: @test_user, admin: nil}
      conn = build_conn_with_scope(scope)

      result = SgiathAuth.require_admin(conn, [])

      assert result.halted
      assert redirected_to(result) == "/"
    end

    test "redirects to sign-in when scope is nil" do
      conn = build_conn_with_scope(nil)

      result = SgiathAuth.require_admin(conn, [])

      assert result.halted
      assert redirected_to(result) == SgiathAuth.WorkOS.sign_in_path()
    end
  end

  describe "on_mount(:require_admin, ...)" do
    test "continues when user is admin" do
      scope = %Scope{user: @test_user, admin: @admin_profile}
      socket = build_socket_with_scope(scope)
      session = %{"access_token" => "valid_token"}

      {:cont, result_socket} = SgiathAuth.on_mount(:require_admin, %{}, session, socket)

      assert result_socket.assigns.current_scope == scope
    end

    test "redirects to / when user is not admin" do
      scope = %Scope{user: @test_user, admin: nil}
      socket = build_socket_with_scope(scope)
      session = %{"access_token" => "valid_token"}

      {:halt, result_socket} = SgiathAuth.on_mount(:require_admin, %{}, session, socket)

      assert {:redirect, %{to: "/"}} = result_socket.redirected
    end

    test "redirects to sign-in when no session" do
      socket = build_socket_with_scope(nil)
      session = %{}

      {:halt, result_socket} = SgiathAuth.on_mount(:require_admin, %{}, session, socket)

      assert {:redirect, %{to: "/sign-in"}} = result_socket.redirected
    end

    test "redirects to refresh when token exists but scope is nil" do
      socket = build_socket_with_scope(nil)
      session = %{"access_token" => "expired_token"}

      {:halt, result_socket} = SgiathAuth.on_mount(:require_admin, %{}, session, socket)

      assert {:redirect, %{to: "/auth/refresh?return_to=/"}} = result_socket.redirected
    end
  end

  # Test helpers

  defp build_conn_with_scope(scope) do
    conn(:get, "/admin")
    |> Plug.Test.init_test_session(%{})
    |> Plug.Conn.assign(:current_scope, scope)
  end

  defp build_socket_with_scope(scope) do
    %Phoenix.LiveView.Socket{
      assigns: %{current_scope: scope, __changed__: %{}},
      private: %{},
      redirected: nil,
      view: TestView
    }
  end

  defp redirected_to(conn) do
    conn.resp_headers
    |> Enum.find(fn {key, _} -> key == "location" end)
    |> elem(1)
  end
end

defmodule TestView do
  def return_to(_params), do: "/"
end
