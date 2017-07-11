defmodule Astarte.Housekeeping.Queries do

  require Logger
  alias CQEx.Query, as: DatabaseQuery
  alias CQEx.Result, as: DatabaseResult

  @create_realm_queries [
    """
      CREATE KEYSPACE :realm_name
        WITH
          replication = {'class': 'SimpleStrategy', 'replication_factor': '1'} AND
          durable_writes = true;
    """,
    """
      CREATE TABLE :realm_name.devices (
        device_id ascii,
        introspection list<ascii>,
        last_connection timestamp,
        last_disconnection timestamp,
        connected boolean,
        protocol_revision int,

        PRIMARY KEY (device_id)
      );
    """,
    """
      CREATE TABLE :realm_name.endpoints (
        endpoint_id uuid,
        interface_name ascii,
        interface_major_version int,
        interface_minor_version int,
        interface_type int,
        endpoint ascii,
        value_type int,
        reliabilty int,
        retention int,
        expiry int,
        allow_unset boolean,

        PRIMARY KEY (endpoint_id)
      );
    """,
    """
      CREATE TABLE :realm_name.interfaces (
        name ascii,
        major_version int,
        minor_version int,
        type int,
        quality int,
        flags int,
        source varchar,
        PRIMARY KEY (name, major_version)
      );
    """,
    """
      INSERT INTO astarte.realms
        (realm_name) VALUES (':realm_name');
    """
  ]

  @create_astarte_queries [
    """
      CREATE KEYSPACE astarte
        WITH
        replication = {'class': 'SimpleStrategy', 'replication_factor': '1'}  AND
        durable_writes = true;
    """,
    """
      CREATE TABLE astarte.realms (
        realm_name varchar,
        PRIMARY KEY (realm_name)
      );
    """,
    """
      CREATE TABLE astarte.astarte_schema (
        config_key varchar,
        config_value varchar,
        PRIMARY KEY (config_key)
      );
    """,
    """
      INSERT INTO astarte.astarte_schema
        (config_key, config_value) VALUES ('schema_version', '0');
    """
  ]

  @realm_exists_query """
    SELECT realm_name FROM astarte.realms WHERE realm_name=:realm_name;
  """

  def create_realm(client, realm_name) do
    if String.match?(realm_name, ~r/^[a-z][a-z0-9]*$/) do
      replaced_queries =
        for query <- @create_realm_queries do
          String.replace(query, ":realm_name", realm_name)
        end
      exec_queries(client, replaced_queries)
    else
      Logger.warn("HouseKeeping.Queries: " <> realm_name <> " is not an allowed realm name.")
      {:error, :realm_not_allowed}
    end

  end

  def create_astarte_keyspace(client) do
    exec_queries(client, @create_astarte_queries)
  end

  def realm_exists?(client, realm_name) do
    query = DatabaseQuery.new
      |> DatabaseQuery.statement(@realm_exists_query)
      |> DatabaseQuery.put(:realm_name, realm_name)

    DatabaseQuery.call!(client, query)
      |> DatabaseResult.size() > 0
  end

  defp exec_queries(client, _queries = [query | tail]) do
    case DatabaseQuery.call(client, query) do
      {:ok, _} -> exec_queries(client, tail)
      %{msg: message} -> {:error, message}
    end
  end

  defp exec_queries(_client, _queries = []) do
    :ok
  end

end
