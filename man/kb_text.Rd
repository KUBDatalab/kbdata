\name{kb_text_search}
\alias{kb_text_search}
\alias{kb_text_get}
\title{Search and retrieve texts from the Text Portal}
\description{
Search for literary texts, get metadata and indexed text where available, or
look up a single document by its Text Portal identifier.
}
\usage{
kb_text_search(
  query = NULL, collection = NULL, author = NULL, category = NULL,
  page = 1L, page_size = 10L, max_pages = 1L, format = c("table", "json"),
  source = c("tekster", "portal")
)

kb_text_get(id, format = c("table", "json"))
}
\arguments{
  \item{query}{An optional search string.}
  \item{collection}{An optional collection code such as \code{"adl"} for
  Arkiv for Dansk Litteratur.}
  \item{author}{An optional exact indexed author name for the Text Portal,
  such as \code{"Munch-Petersen, Gustaf"}. The table column
  \code{author_key} gives the indexed spelling. The legacy source uses
  a tokenized author query instead.}
  \item{category}{An optional record type such as \code{"work"},
  \code{"volume"} or \code{"leaf"}. Use \code{"editorial"} for
  editorial records.}
  \item{page}{First page to retrieve, starting at 1.}
  \item{page_size}{Number of records per request, from 1 to 100.}
  \item{max_pages}{Maximum number of pages to retrieve, or \code{Inf}.}
  \item{format}{A data frame or decoded JSON.}
  \item{source}{\code{"tekster"} uses the public Text Portal.
  \code{"portal"} uses the legacy Solr endpoint on \code{api.kb.dk},
  which returned HTTP 500 for documented requests during development.}
  \item{id}{A document identifier from the Text Portal.}
}
\value{
A data frame with one row per record. The \code{text} column contains
indexed text when available. The \code{source_path} and \code{xml_id}
columns identify the corresponding TEI element for ADL records. With
\code{format = "json"}, a search returns a list of decoded page responses
and a lookup returns the decoded document response. A search also carries
the attributes \code{kb_total}, \code{kb_pages_fetched} and \code{kb_source}.
}
\seealso{\code{\link{kb_adl_text}} for ADL source documents.}
\examples{
\dontrun{
hits <- kb_text_search("Jerusalem", collection = "adl",
                       author = "Munch-Petersen, Gustaf", category = "work")
if (nrow(hits) > 0L) kb_text_get(hits$id[[1L]])
}
}
