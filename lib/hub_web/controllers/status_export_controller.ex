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

  @chromium "/Users/pv/Library/Caches/ms-playwright/chromium-1208/chrome-mac-arm64/Google Chrome for Testing.app/Contents/MacOS/Google Chrome for Testing"

  defp build_export(folder, status_path, name) do
    safe_name = String.replace(name, ~r/[^\w\s\-]/, "") |> String.trim()
    pdf_path  = "/tmp/hub_status_#{folder}.pdf"
    html_path = "/tmp/hub_status_#{folder}.html"

    cond do
      not File.exists?(status_path) ->
        txt = "/tmp/hub_status_#{folder}.md"
        File.write!(txt, "No STATUS.md found.")
        {txt, "text/plain", "#{safe_name} - Status.md"}

      # markdown → HTML via pandoc, then HTML → PDF via Chrome headless
      match?({_, 0}, System.cmd("pandoc", [status_path, "--standalone", "-o", html_path], stderr_to_stdout: true)) ->
        chrome_ok =
          File.exists?(@chromium) &&
          match?({_, 0}, System.cmd(@chromium,
            ["--headless", "--disable-gpu", "--no-sandbox", "--print-to-pdf=#{pdf_path}", "file://#{html_path}"],
            stderr_to_stdout: true))

        if chrome_ok && File.exists?(pdf_path) do
          {pdf_path, "application/pdf", "#{safe_name} - Status.pdf"}
        else
          {html_path, "text/html", "#{safe_name} - Status.html"}
        end

      true ->
        {status_path, "text/plain", "#{safe_name} - Status.md"}
    end
  end
end
