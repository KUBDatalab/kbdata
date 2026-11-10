library(kbdata)

response <- function(body, headers = list(), type = "application/json") {
  structure(list(
    url = "https://example.invalid", status_code = 200L,
    headers = c(list("content-type" = type), headers),
    content = charToRaw(body)
  ), class = "response")
}

# COP counts pages in Pagination-Count. DSfL counts photographs instead.
result <- response('[{"title":"Example","identifier":null}]', list(
  "pagination-count" = "2", "pagination-limit" = "2", total = "4"
))
cop <- kbdata:::kb_rest_page(result, page = 2, page_size = 2)
stopifnot(cop$total == 4, cop$last)

result <- response('[{"type":"Feature"}]', list(
  "pagination-count" = "4", "pagination-limit" = "2"
))
first <- kbdata:::kb_rest_page(result, page = 1, page_size = 2, aerial = TRUE)
last <- kbdata:::kb_rest_page(result, page = 2, page_size = 2, aerial = TRUE)
stopifnot(first$total == 4, !first$last, last$last)

seen <- numeric()
fetch <- function(page) {
  seen <<- c(seen, page)
  records <- list(list(title = paste("Page", page)))
  list(body = records, records = records, total = 3, last = page == 3)
}
pages <- kbdata:::kb_collect(fetch, page = 2, max_pages = Inf)
stopifnot(identical(seen, c(2, 3)), length(pages) == 2,
          attr(pages, "kb_total") == 3, attr(pages, "kb_pages_fetched") == 2)

empty <- kbdata:::kb_cop_table(list())
stopifnot(nrow(empty) == 0L, is.character(empty$id))
stopifnot(identical(
  kbdata:::kb_bbox(c(xmax = 10.70, ymax = 55.52, xmin = 10.65, ymin = 55.47)),
  kbdata:::kb_bbox(c(10.65, 55.47, 10.70, 55.52))
))

kml <- paste0(
  '<kml xmlns="http://www.opengis.net/kml/2.2"><Document>',
  '<totalResults xmlns="http://a9.com/-/spec/opensearch/1.1/">1</totalResults>',
  '<startIndex xmlns="http://a9.com/-/spec/opensearch/1.1/">1</startIndex>',
  '<Placemark id="object1"><name>Example</name>',
  '<Point><coordinates>10.69,55.49</coordinates></Point>',
  '</Placemark></Document></kml>'
)
feed <- kbdata:::kb_xml_page(response(kml, type = "application/xml"), "kml", 2)
photos <- kbdata:::kb_dsfl_table(as.list(feed$records))
stopifnot(feed$total == 1, feed$last,
          photos$id == "object1", photos$longitude == 10.69, photos$latitude == 55.49)
