defmodule CompassAdmin.Services.SitemapGenerate do
  alias CompassAdmin.Repo
  alias CompassAdmin.ShortenedLabel

  import Ecto.Query

  @host "https://oss-compass.org"

  def start() do
    config = [
      store: Sitemapper.FileStore,
      store_config: [
        path: Path.join(:code.priv_dir(:compass_admin), "static/sitemaps")
      ],
      sitemap_url: "#{@host}/sitemaps",
    ]
    stream = Repo.stream(from(s in ShortenedLabel, select: s), max_rows: 1000)
    Repo.transaction(fn ->
      stream
      |> Stream.map(fn s ->
        %Sitemapper.URL{
          loc: "#{@host}/analyze/#{s.short_code}",
          changefreq: :daily,
          lastmod: Date.utc_today()
}
      end)
      |> Sitemapper.generate(config)
      |> Sitemapper.persist(config)
      |> Stream.run()
    end)
    IO.puts("Sitemap generation done")
  end
end
