defmodule DashboardWeb.Live.AboutLive do
  use DashboardWeb, :live_view

  def about_page(assigns) do
    ~H"""
    <div class="about-container">
      <div class="header-wrapper"><h1> csv2sql blazing fast csv to sql loader </h1></div>
      <div><a href="https://github.com/kreeti/csv2sql" target="blank"> <i class="fa fa-github-square" aria-hidden="true"></i>Want to know more check out the project on github!</a></div>
    </div>
    """
  end
end
