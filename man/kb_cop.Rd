\name{kb_cop_search}
\alias{kb_cop_editions}
\alias{kb_cop_search}
\alias{kb_cop_navigation}
\alias{kb_cop_images}
\title{Search the Royal Danish Library's digital collections}
\description{
List collection editions, search an edition, look up a subject tree, or
retrieve links to the images of an object from its MODS record.
}
\usage{
kb_cop_editions()

kb_cop_search(
  edition, query = NULL, not_before = NULL, not_after = NULL,
  page = 1L, page_size = 30L, max_pages = 1L,
  format = c("table", "json", "rss", "kml", "mods")
)

kb_cop_navigation(edition, subject, format = c("table", "opml"))

kb_cop_images(id)
}
\arguments{
  \item{edition}{A COP edition or subject path, or a KB URL with that path.
  Use \code{kb_cop_editions()$id} to discover editions. For a single record,
  supply its complete object path, including the edition.}
  \item{query}{An optional search string.}
  \item{not_before,not_after}{Optional date bounds as \code{Date} objects or
  strings in YYYY-MM-DD format.}
  \item{page}{First page to retrieve, starting at 1.}
  \item{page_size}{Number of records per request, from 1 to 500.}
  \item{max_pages}{Maximum number of pages to retrieve. Use \code{Inf} to
  continue until the service reports the end of the result set.}
  \item{format}{Return a data frame or a parsed JSON or XML response in the
  requested format.}
  \item{subject}{A COP subject identifier such as \code{"subject841"} or
  \code{"841"}.}
  \item{id}{The full COP path or KB URL of an individual object.}
}
\value{
\code{kb_cop_editions()} and a default search return data frames with
\code{id}, \code{title}, \code{description}, \code{url},
\code{thumbnail_url} and \code{image_url}. Search formats other than
\code{"table"} return a list with one decoded response per page. Searches
carry the attributes \code{kb_total} and \code{kb_pages_fetched}.

\code{kb_cop_navigation()} returns subject IDs and parent IDs, Danish and
English titles, and links. With \code{format = "opml"} it returns the
complete XML document. \code{kb_cop_images()} returns image titles and IIIF
information, full image, and thumbnail URLs in MODS order, where available.
}
\examples{
\dontrun{
editions <- kb_cop_editions()
kb_cop_search("/images/billed/2010/okt/billeder/da/", "Kierkegaard")
kb_cop_navigation("/images/billed/2010/okt/billeder/da/", "841")
kb_cop_images("/manus/musman/2010/dec/viser/object23942/en/")
}
}
