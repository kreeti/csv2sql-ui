defmodule DashboardWeb.Live.StartLive do
  use DashboardWeb, :live_view

  def start_page(assigns) do
    ~H"""
    <div class="main-container">
      <div class="current-stats">
        <div>
          <strong> Status: </strong>
          <span class={"overall-status #{error_status_class(@state.status)}"}>
            <%= cond do %>
              <% not @changeset.valid? -> %>
                Invalid Configurations!

              <% is_tuple(@state.status) -> %>
                Error! check logs

              <% true -> %>
                <%= show_status(@state.status) %>
            <% end %>
          </span>
        </div>
        <%= if not is_nil(@state.validation_status) do %>
          <div>
              <strong> Validation Status: </strong>
              <span class={"validation-status #{error_status_class(@state.validation_status)}"}><%= @state.validation_status %>!</span>
          </div>
        <% end %>
        <%= if @state.status != :init do %>
          <div><strong> Total Files: </strong><%= Enum.count(Map.values(@state.files)) %> </div>
          <div><strong> Files Imported: </strong><%= Enum.count(Map.values(@state.files), fn %{status: status} -> status == :done end) %> </div>
          <div><strong> CPU Usage: </strong> <%= @cpu_usage %>% </div>
          <div><strong> Memory Usage of Application: </strong>  <%= @memory_usage %></div>
          <div><strong> Time Elapsed: </strong> <%= @time_spend %> seconds </div>
        <% end %>
      </div>

      <div class="file-list list-group">

        <%= Enum.map Map.values(@state.files), fn %{name: name, path: path, size: size, row_count: row_count, rows_processed: rows_processed, status: status} -> %>
          <div class={"file-list-item list-group-item list-group-item-action #{item_success_class(status)} "}>
            <span class="file-name"> <strong> Name: </strong>
              <%= name %>
            </span>
            <span class="file-path"> <strong> Path: </strong> <a href={"file:///#{path}"} target="_blank">
                <%= path %>
              </a> </span>
            <span class="file-size"> <strong> Size: </strong>
              <%= size %>
            </span>
            <span class="row_count"> <strong> Total Number of Records: </strong>
              <%= row_count %>
            </span>
            <span>
              <strong class="status"> Status: </strong>
              <%= case status do %>
                <% :pending -> %> <span class="stage_pending"> Pending </span>

                <% :analyze -> %> <span class="stage_infer_schema"> Infering Schema </span>

                <% :loading -> %>
                  <span class="stage_insert_data"> Inserting Data </span>
                  <span class="records_inserted"> <strong> Record Inserted: </strong>
                    <%= rows_processed %>
                  </span>
                  <div class="progress">
                    <% percentage_progress=if(row_count==0, do: 100, else: (rows_processed / row_count) * 100) %>
                    <div class="progress-bar progress-bar-striped progress-bar-animated bg-success"
                      role="progressbar" style={"width: #{percentage_progress}%"}>
                      <span class="progress-percentage justify-content-center d-flex position-absolute w-100">
                        <%= Float.round(percentage_progress * 1.0 , 2) %>%
                      </span>
                    </div>
                  </div>

                <% :done -> %> <span class="stage_finished"> Finished </span>
              <% end %>
            </span>
          </div>
        <% end %>

      </div>

    </div>
    <footer class="main-footer fixed-bottom">
      <div class={"container #{button_class(@changeset)}"} phx-click="start">
        <div id="divSpinner" class={spinner_loading_class(@state.status)} >
          <div id="spinnerText">
          <%= cond do %>
            <% @state.status == :init -> %> <span> Start!</span>
            <% @state.status in [:working, :imported] -> %> <span> Working.. </span>
            <% @state.status == :validating -> %> <span> Validating.. </span>
            <% @state.status == :finish -> %> <span> Finished!  Reset? </span>
            <% true -> %> <span id="error_stage" role="button" phx-click="page-change" phx-value-page="start"> ERROR! Reset?</span>
          <% end %>
          </div>
        </div>
      </div>
    </footer>
    """
  end

  defp item_success_class(status) do
    if status == :done, do: "list-group-item-success", else: ""
  end

  defp error_status_class(status) do
    if is_tuple(status) or status == :failed, do: "error-status", else: ""
  end

  defp spinner_loading_class(status) do
    if status in [:working, :imported, :validating],
      do: "spinner loading",
      else: ""
  end

  defp show_status(:imported), do: :working

  defp show_status(status), do: status

  defp button_class(changeset) do
    if not changeset.valid?, do: "button-disabled", else: "button-enabled"
  end
end
