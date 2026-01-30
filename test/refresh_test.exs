defmodule SgiathAuth.RefreshTest do
  use ExUnit.Case, async: false

  import Plug.Conn
  import Plug.Test

  @workos_stub __MODULE__

  setup do
    Req.Test.set_req_test_to_shared()

    original_client_id = Application.get_env(:sgiath_auth, :workos_client_id)
    original_secret = Application.get_env(:sgiath_auth, :workos_secret_key)
    original_req_options = Application.get_env(:sgiath_auth, :workos_req_options)

    Application.put_env(:sgiath_auth, :workos_client_id, "client_test")
    Application.put_env(:sgiath_auth, :workos_secret_key, "secret_test")
    Application.put_env(:sgiath_auth, :workos_req_options, plug: {Req.Test, @workos_stub})

    on_exit(fn ->
      Application.put_env(:sgiath_auth, :workos_client_id, original_client_id)
      Application.put_env(:sgiath_auth, :workos_secret_key, original_secret)
      Application.put_env(:sgiath_auth, :workos_req_options, original_req_options)
    end)

    :ok
  end

  test "GET refresh is accepted" do
    Req.Test.stub(@workos_stub, fn conn ->
      Req.Test.json(conn, %{
        "access_token" => "access_new",
        "refresh_token" => "refresh_new"
      })
    end)

    conn =
      conn("GET", "/auth/refresh")
      |> init_test_session(%{refresh_token: "refresh_old"})

    conn = SgiathAuth.Controller.refresh(conn, %{})

    assert get_session(conn, :access_token) == "access_new"
    assert get_session(conn, :refresh_token) == "refresh_new"
    assert conn.status == 302
  end

  test "refresh_session forwards organization_id and updates session" do
    Req.Test.stub(@workos_stub, fn conn ->
      body =
        conn
        |> Req.Test.raw_body()
        |> IO.iodata_to_binary()

      send(self(), {:refresh_body, body})

      Req.Test.json(conn, %{
        "access_token" => "access_new",
        "refresh_token" => "refresh_new",
        "organization_id" => "org_123"
      })
    end)

    conn =
      conn("POST", "/auth/refresh")
      |> init_test_session(%{refresh_token: "refresh_old"})

    conn = SgiathAuth.refresh_session(conn, %{"organization_id" => "org_123"})

    assert get_session(conn, :access_token) == "access_new"
    assert get_session(conn, :refresh_token) == "refresh_new"
    assert get_session(conn, :org_id) == "org_123"

    assert_receive {:refresh_body, body}
    assert body =~ "\"organization_id\":\"org_123\""
  end

  @tag :capture_log
  test "refresh_session clears session on WorkOS error" do
    Req.Test.stub(@workos_stub, fn conn ->
      send_resp(conn, 422, "invalid")
    end)

    conn =
      conn("POST", "/auth/refresh")
      |> init_test_session(%{refresh_token: "refresh_old", access_token: "access_old"})

    conn = SgiathAuth.refresh_session(conn, %{"organization_id" => "org_123"})

    assert get_session(conn) == %{}
  end
end
