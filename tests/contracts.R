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
stopifnot(identical(
  kbdata:::kb_dsfl_image_url(c(
    "http://www.kb.dk/imageService/w150/h150/archive/photo.jpg",
    "http://kb-images.kb.dk/archive/other/full/,100/0/native.jpg",
    NA_character_
  ), ",150"),
  c("https://kb-images.kb.dk/archive/photo/full/,150/0/native.jpg",
    "https://kb-images.kb.dk/archive/other/full/,100/0/native.jpg", NA_character_)
))

# The spring clock change makes this local broadcast day 23 hours long.
params <- kbdata:::kb_dr_query(NULL, "tv", c("DR 1", "DR 2"), NULL,
                               "2024-03-31", "2024-03-31")
stopifnot(identical(unname(unlist(params[names(params) == "fq"])), c(
  'origin:"ds.tv"', '(creator_affiliation_facet:"DR 1" OR creator_affiliation_facet:"DR 2")',
  "startTime:[2024-03-30T23:00:00Z TO 2024-03-31T22:00:00Z}"
)))

seen <- numeric()
limit_warning <- FALSE
limited <- withCallingHandlers(
  kbdata:::kb_collect(fetch, page = 1L, max_pages = Inf, last_page = 2L),
  warning = function(condition) {
    limit_warning <<- grepl("pagination limit", conditionMessage(condition))
    invokeRestart("muffleWarning")
  }
)
stopifnot(limit_warning, identical(seen, c(1, 2)), length(limited) == 2L,
          attr(limited, "kb_total") == 3)

empty <- kbdata:::kb_dr_table(list())
stopifnot(nrow(empty) == 0L, inherits(empty$start_time, "POSIXct"),
          inherits(empty$broadcast_date, "Date"), is.character(empty$url))
