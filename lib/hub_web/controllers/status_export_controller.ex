defmodule HubWeb.StatusExportController do
  use HubWeb, :controller

  def download(conn, %{"folder" => folder}) do
    project = Hub.ProjectScanner.scan() |> Enum.find(&(&1.folder == folder))

    if project do
      status_path = Path.join(project.path, "STATUS.md")
      {file_path, content_type, filename} = build_export(folder, status_path, project.name)

      conn
      |> put_resp_content_type(content_type)
      |> put_resp_header("content-disposition", ~s(attachment; filename="#{filename}"))
      |> send_file(200, file_path)
    else
      conn |> put_status(404) |> text("Project not found")
    end
  end

  defp build_export(folder, status_path, name) do
    safe_name = String.replace(name, ~r/[^\w\s\-]/, "") |> String.trim()
    pdf_path  = "/tmp/hub_status_#{folder}.pdf"
    html_path = "/tmp/hub_status_#{folder}.html"

    cond do
      not File.exists?(status_path) ->
        txt = "/tmp/hub_status_#{folder}.md"
        File.write!(txt, "No STATUS.md found.")
        {txt, "text/plain", "#{safe_name} - Status.md"}

      match?({_, 0}, System.cmd("pandoc", [status_path, "-o", pdf_path], stderr_to_stdout: true)) ->
        {pdf_path, "application/pdf", "#{safe_name} - Status.pdf"}

      match?({_, 0}, System.cmd("pandoc", [status_path, "--standalone", "-o", html_path], stderr_to_stdout: true)) ->
        {html_path, "text/html", "#{safe_name} - Status.html"}

      true ->
        {status_path, "text/plain", "#{safe_name} - Status.md"}
    end
  end
end
