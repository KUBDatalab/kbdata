\name{kb_dsfl_search}
\alias{kb_dsfl_search}
\title{Find aerial photographs in a geographic area}
\description{
Search the Danmark set fra Luften collection by bounding box, with optional
filters for search terms, dates, and photo type.
}
\usage{
kb_dsfl_search(
  bbox, query = NULL, not_before = NULL, not_after = NULL,
  type = c("all", "oblique", "vertical", "protocol"),
  page = 1L, page_size = 50L, max_pages = 1L,
  format = c("table", "json", "rss", "kml", "mods")
)
}
\arguments{
  \item{bbox}{Four WGS 84 coordinates in decimal degrees, ordered west,
  south, east, north. A named vector with \code{xmin}, \code{ymin},
  \code{xmax}, and \code{ymax} may be given in any order.}
  \item{query}{An optional search string.}
  \item{not_before,not_after}{Optional date bounds as \code{Date} objects or
  strings in YYYY-MM-DD format.}
  \item{type}{Filter for all entries, oblique or vertical aerial photographs,
  or protocol pages.}
  \item{page}{First page to retrieve, starting at 1.}
  \item{page_size}{Number of records per request, from 1 to 500.}
  \item{max_pages}{Maximum number of pages to retrieve, or \code{Inf}.}
  \item{format}{\code{"table"} for a data frame based on KML, \code{"json"}
  for point features, or \code{"rss"}, \code{"kml"} or \code{"mods"} for
  parsed XML. Use the table or an XML format with search, date and type filters.}
}
\value{
A data frame with IDs, titles, numeric longitude and latitude, location,
photographer, date, type and URLs, or a list with one decoded response per
page. The attributes \code{kb_total} and \code{kb_pages_fetched} give
the number of matching photographs and pages fetched.
}
\examples{
\dontrun{
kb_dsfl_search(c(10.65, 55.47, 10.70, 55.52), type = "vertical")
}
}
