defmodule DashboardWeb.Live.MainLive do
  use DashboardWeb, :live_view
  import Dashboard.Helpers
  alias DashBoard.Config
  alias DashBoard.DbAttribute
  alias Csv2sql.Database.ConnectionTest
  alias DashboardWeb.Live.{ConfigLive, StartLive, AboutLive}

  @debounce_time 1000

  @impl true
  def mount(_params, _session, socket) do
    local_storage_config = (get_connect_params(socket) || %{}) |> Map.get("localConfig", %{})

    local_storage_config =
      for {key, val} <- local_storage_config, into: %{}, do: {String.to_atom(key), val}

    # Check for DB connection on config load from local storage
    timer_ref = Process.send_after(self(), :check_db_connection, @debounce_time)

    {:ok,
     assign(socket,
       page: "config",
       modal: false,
       path_validator_debouncer: nil,
       db_connection_debouncer: timer_ref,
       db_connection_established: false,
       changeset: Config.get_defaults() |> Map.merge(local_storage_config) |> Config.changeset(),
       matching_date_time: nil,
       constraints: Csv2sql.Config.Loader.get_constraints(),
       time_spend: 0,
       state: %Csv2sql.ProgressTracker.State{
         status: :init,
         start_time: nil,
         validation_status: nil
       },
       memory_usage: 0,
       cpu_usage: 0
     )}
  end

  @impl true
  def handle_event("start", _unsigned_params, %{assigns: assigns} = socket) do
    socket_state = assigns.state

    cond do
      assigns.changeset.valid? and socket_state.status == :init ->
        Csv2sql.ProgressTracker.add_subscriber()

        Task.start(fn ->
          socket.assigns.changeset
          |> prepare_args()
          |> Csv2sql.Config.Loader.load()

          Csv2sql.Stages.Analyze.analyze_files()
        end)

        send(self(), :update_state)

        {:noreply, socket}

      socket_state.status == :working or is_nil(socket_state.validation_status) ->
        {:noreply, socket}

      true ->
        Csv2sql.ProgressTracker.reset_state()

        {:noreply,
         assign(socket,
           state: %Csv2sql.ProgressTracker.State{
             status: :init,
             start_time: nil,
             validation_status: nil
           },
           time_spend: 0,
           memory_usage: 0,
           cpu_usage: 0
         )}
    end
  end

  @impl true
  def handle_event("page-change", %{"page" => page}, socket) do
    {:noreply, assign(socket, %{page: page})}
  end

  @impl true
  def handle_event("open-modal", %{"modal" => modal}, socket) do
    {:noreply, assign(socket, :modal, modal)}
  end

  @impl true
  def handle_event("close-modal", _attrs, socket) do
    {:noreply, assign(socket, :modal, false)}
  end

  @impl true
  def handle_event("validate-and-save", attrs, socket) do
    args = Map.get(attrs, "config", %{})

    socket =
      socket
      |> assign(
        page: "config",
        changeset: Config.changeset(args)
      )
      # DB connection checker is expensive and returns result to caller process with delay
      # so we don't do this validation on changeset level
      |> db_connection_checker(args)
      |> update_matching_date_time(attrs)

    {:noreply, socket |> push_event("save-config", %{config: socket.assigns.changeset})}
  end

  @impl true
  def handle_event("add-new-" <> field, _attrs, %{assigns: assigns} = socket)
      when field in ~w[db-attr date-pattern date-time-pattern] do
    new_field =
      field
      |> String.replace("-", "_")
      |> String.to_atom()
      |> case do
        :db_attr -> %DbAttribute{id: Nanoid.generate(), name: "", value: ""}
        :date_pattern -> %DashBoard.DatePattern{id: Nanoid.generate()}
        :date_time_pattern -> %DashBoard.DateTimePattern{id: Nanoid.generate()}
      end

    association = "#{field}s" |> String.replace("-", "_") |> String.to_atom()

    updated_association =
      assigns.changeset
      |> Ecto.Changeset.get_field(association, [])
      |> Enum.concat([new_field])

    updated_changeset =
      Ecto.Changeset.put_embed(assigns.changeset, association, updated_association)

    {:noreply,
     socket
     |> assign(changeset: updated_changeset)
     |> push_event("scroll-to-bottom", %{id: "#{field}s-container"})}
  end

  @impl true
  def handle_event("remove-" <> field, %{"attrid" => attrid}, %{assigns: assigns} = socket)
      when field in ~w[db-attr date-pattern date-time-pattern] do
    association = "#{field}s" |> String.replace("-", "_") |> String.to_atom()

    updated_association =
      assigns.changeset
      # For relations get_change/2 return the original changeset data with changes applied, fetch_change!/2 returns raw db_config changesets
      |> Ecto.Changeset.fetch_change!(association)
      |> Enum.reject(fn embed_changeset ->
        Ecto.Changeset.get_field(embed_changeset, :id) == attrid
      end)

    updated_changeset =
      Ecto.Changeset.put_embed(assigns.changeset, association, updated_association)

    {:noreply,
     socket
     |> assign(changeset: updated_changeset)
     |> update_matching_date_time()}
  end

  @impl true
  def handle_info(:finish, socket) do
    {:noreply, assign(socket, state: Csv2sql.ProgressTracker.get_state())}
  end

  @impl true
  def handle_info(:update_state, socket) do
    state = socket.assigns.state

    time_taken =
      if is_nil(state.start_time) do
        0
      else
        DateTime.utc_now()
        |> Time.diff(state.start_time, :millisecond)
        |> Kernel./(1000)
        |> Float.round()
      end

    if state.status in [:init, :working] or is_nil(state.validation_status) do
      Process.send_after(self(), :update_state, 200)
    end

    {:noreply,
     assign(socket,
       state: Csv2sql.ProgressTracker.get_state(),
       time_spend: time_taken,
       cpu_usage: :cpu_sup.util() |> Float.round(2),
       memory_usage: :erlang.memory(:total) |> Sizeable.filesize()
     )}
  end

  @impl true
  def handle_info(:check_db_connection, %{assigns: assigns} = socket) do
    with(
      db_url = create_db_url(assigns.changeset.changes, hide_password: false),
      true <- not ("NA" == db_url),
      db_type <- Ecto.Changeset.get_field(assigns.changeset, :db_type),
      false <- is_nil(db_type),
      args = %{db_type: db_type, db_url: db_url},
      resp = ConnectionTest.check_db_connection(self(), args),
      :ok <- resp
    ) do
      socket
    else
      {:error, :on_going} ->
        Process.send_after(self(), :check_db_connection, @debounce_time)
        socket

      _ ->
        assign(socket, db_connection_established: false)
    end

    {:noreply, socket}
  end

  # DB connection callbacks
  @impl true
  def handle_info({:connected, _}, socket),
    do: {:noreply, assign(socket, db_connection_established: true)}

  @impl true
  def handle_info({:error, _}, %{assigns: assigns} = socket) do
    {:noreply,
     assign(
       socket,
       changeset:
         Ecto.Changeset.add_error(assigns.changeset, :db_url, "Could not connect to database"),
       db_connection_established: false
     )}
  end

  @impl true
  def handle_info({:report_error, reason}, socket) do
    IO.inspect("Reported Error #{inspect(reason)}")
    {:noreply, socket}
  end

  defp render_page(assigns) do
    case assigns.page do
      "config" ->
        ConfigLive.config_page(assigns)

      "start" ->
        StartLive.start_page(assigns)

      "about" ->
        AboutLive.about_page(assigns)
    end
  end

  defp db_connection_checker(%{assigns: assigns} = socket, args) do
    if db_config_updated?(assigns, args) do
      if assigns.db_connection_debouncer,
        do: Process.cancel_timer(assigns.db_connection_debouncer)

      timer_ref = Process.send_after(self(), :check_db_connection, @debounce_time)
      assign(socket, :db_connection_debouncer, timer_ref)
    else
      socket
    end
  end

  defp db_config_updated?(%{changeset: changeset}, args) do
    # TODO: Take into account custom db params
    Ecto.Changeset.get_field(changeset, :db_type) != Map.get(args, "db_type") ||
      Ecto.Changeset.get_field(changeset, :db_username) != Map.get(args, "db_username") ||
      Ecto.Changeset.get_field(changeset, :db_password) != Map.get(args, "db_password") ||
      Ecto.Changeset.get_field(changeset, :db_host) != Map.get(args, "db_host") ||
      Ecto.Changeset.get_field(changeset, :db_name) != Map.get(args, "db_name")
  end

  defp update_matching_date_time(%{assigns: assigns} = socket, attrs \\ %{}) do
    date_time_sample =
      get_in(attrs, ["config", "date_time_trial"]) ||
        Ecto.Changeset.get_field(assigns.changeset, :date_time_trial)

    case match_date_time(assigns.changeset, date_time_sample) do
      {type, index} ->
        socket
        |> assign(matching_date_time: {type, index})
        |> push_event("scroll-into-view", %{
          id: "config_#{type}_patterns_#{index}_pattern"
        })

      false ->
        assign(socket, matching_date_time: nil)
    end
  end

  defp prepare_args(changeset) do
    config = Ecto.Changeset.apply_changes(changeset)

    %{
      source_directory: config.source_directory,
      schema_path: config.schema_path,
      insert_schema: config.insert_schema,
      insert_data: config.insert_data,
      ordered: config.ordered,
      date_patterns: prepare_date_patterns(config.date_patterns),
      datetime_patterns: prepare_date_patterns(config.date_time_patterns),
      schema_infer_chunk_size: config.schema_infer_chunk_size,
      worker_count: config.worker_count,
      parse_datetime: config.parse_datetime,
      remove_illegal_characters: config.remove_illegal_characters,
      db_type: config.db_type,
      db_name: config.db_name,
      db_url: create_db_url(changeset.changes),
      drop_existing_tables: config.drop_existing_tables,
      varchar_limit: config.varchar_limit,
      db_worker_count: config.db_worker_count,
      insertion_chunk_size: config.insertion_chunk_size,
      log: config.log
    }
  end

  defp prepare_date_patterns(date_patterns) do
    date_patterns
    |> Enum.reject(&is_nil(&1.pattern))
    |> Enum.map(&%{id: &1.id, pattern: &1.pattern})
  end
end
