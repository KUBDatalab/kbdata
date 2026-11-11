\name{kb_dr_search}
\alias{kb_dr_search}
\alias{kb_dr_get}
\alias{kb_dr_facets}
\title{Search the Royal Danish Library's DR archive}
\description{
Find radio and television broadcasts, retrieve a catalogue record, or count
matching records by channel, genre, and year. The package opens an anonymous
session with the archive's web interface.
}
\usage{
kb_dr_search(query = NULL, media = c("all", "radio", "tv"),
  channel = NULL, genre = NULL, not_before = NULL, not_after = NULL,
  sort = c("relevance", "newest", "oldest"), page = 1L, page_size = 20L,
  max_pages = 1L, format = c("table", "json"))

kb_dr_get(id, format = c("table", "json"))

kb_dr_facets(query = NULL, media = c("all", "radio", "tv"),
  channel = NULL, genre = NULL, not_before = NULL, not_after = NULL)
}
\arguments{
\item{query}{Search expression sent to the archive. Double quotes inside the
string specify a phrase. \code{NULL} matches all records.}
\item{media}{Include both media, radio only, or television only.}
\item{channel, genre}{Character vectors of exact archive facet values.
Multiple values in the same vector are alternatives. Use
\code{kb_dr_facets()} to see available values.}
\item{not_before, not_after}{Inclusive broadcast dates as \code{Date} values
or strings in YYYY-MM-DD format, interpreted in Europe/Copenhagen.}
\item{sort}{Order by relevance or broadcast time. The record ID breaks ties.}
\item{page}{One-based starting page.}
\item{page_size}{Number of records requested per page, up to 5000.}
\item{max_pages}{Maximum number of pages to fetch. \code{Inf} fetches pages
until the results end or the archive's pagination limit is reached.}
\item{format}{Return an analysis-ready table or parsed JSON.}
\item{id}{A single record ID from a search result.}
}
\details{
The archive accepts a zero-based start offset up to 2000. If this prevents
fetching a requested subsequent page, the function returns the retrieved pages
with a warning. Date, channel, and genre filters narrow the result set.

Search and detail tables contain the broadcast date in Copenhagen time, start
and end times as UTC \code{POSIXct} values, duration in seconds, descriptive
fields, and a link to the broadcast page. The catalogue contains records with
missing metadata, represented as \code{NA} in the table.
}
\value{
\code{kb_dr_search()} returns a data frame or a list of parsed search pages.
Both have \code{kb_total} and \code{kb_pages_fetched} attributes.

\code{kb_dr_get()} returns a one-row data frame or a named list of descriptive
JSON-LD fields.

\code{kb_dr_facets()} returns a data frame with \code{facet}, \code{value},
and \code{count} columns and a \code{kb_total} attribute. Facet counts describe
the entire filtered search result.
}
\seealso{
\url{https://www.kb.dk/find-materiale/soegeindgange/dr-arkivet}
}
\examples{
\dontrun{
programmes <- kb_dr_search('"Bamse og Kylling"', media = "tv", page_size = 5)
if (nrow(programmes) > 0L) kb_dr_get(programmes$id[[1L]])

counts <- kb_dr_facets('"P1 Debat"', media = "radio")
subset(counts, facet == "channel")
}
}
