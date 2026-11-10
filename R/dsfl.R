kb_dsfl_search <- function(bbox, query = NULL, not_before = NULL,
                           not_after = NULL,
                           type = c("all", "oblique", "vertical", "protocol"),
                           page = 1L, page_size = 50L, max_pages = 1L,
                           format = c("table", "json", "rss", "kml", "mods")) {
  format <- match.arg(format)
  type <- match.arg(type)
  bbo <- kb_bbox(bbox)
  kb_check_string(query, "query", optional = TRUE)
  kb_check_integer(page_size, "page_size", max = 500L)
  dates <- kb_dates(not_before, not_after)

  if (format == "json") {
    if (type != "all" || !is.null(query) || any(!vapply(dates, is.null, logical(1)))) {
      stop('For aerial photo filters, use format = "table" or an XML format.',
           call. = FALSE)
    }
    fetch_page <- function(page) {
      response <- kb_get(paste0(kb_portal, "/dsfl"), list(
        bbo = bbo, page = page, itemsPerPage = page_size
      ))
      kb_rest_page(response, page, page_size, aerial = TRUE)
    }
    return(kb_collect(fetch_page, page, max_pages))
  }

  feed_format <- if (format == "table") "kml" else format
  photo_type <- c(all = "all", oblique = "1", vertical = "2", protocol = "3")[[type]]
  url <- paste0(kb_syndication, "/images/luftfo/2011/maj/luftfoto/subject203/")
  fetch_page <- function(page) {
    response <- kb_get(url, list(
      bbo = bbo, format = feed_format, query = query, type = photo_type,
      notBefore = dates$not_before, notAfter = dates$not_after,
      page = page, itemsPerPage = page_size
    ))
    kb_xml_page(response, feed_format, page_size)
  }
  table <- if (format == "table") kb_dsfl_table else NULL
  kb_collect(fetch_page, page, max_pages, table)
}

kb_bbox <- function(bbox) {
  if (!is.numeric(bbox) || length(bbox) != 4L || any(!is.finite(bbox))) {
    stop("bbox must contain four finite coordinates in WGS 84.", call. = FALSE)
  }
  coord_names <- c("xmin", "ymin", "xmax", "ymax")
  if (!is.null(names(bbox))) {
    if (!setequal(names(bbox), coord_names)) {
      stop("Named bbox coordinates must be xmin, ymin, xmax and ymax.",
           call. = FALSE)
    }
    bbox <- bbox[coord_names]
  }
  bbox <- as.numeric(bbox)
  if (bbox[1L] < -180 || bbox[3L] > 180 || bbox[2L] < -90 || bbox[4L] > 90 ||
      bbox[1L] >= bbox[3L] || bbox[2L] >= bbox[4L]) {
    stop("bbox must be ordered west, south, east, north within WGS 84 bounds.",
         call. = FALSE)
  }
  # KB uses the north-east corner first and longitude first within each corner.
  paste(format(bbox[c(3L, 4L, 1L, 2L)], trim = TRUE, scientific = FALSE,
               digits = 16L, decimal.mark = "."), collapse = ",")
}

kb_dsfl_table <- function(nodes) {
  properties <- lapply(nodes, function(node) {
    data <- xml2::xml_find_all(node, "./*[local-name()='ExtendedData']/*[local-name()='Data']")
    values <- lapply(data, kb_xml_text, xpath = "./*[local-name()='value']")
    names(values) <- xml2::xml_attr(data, "name")
    values
  })
  coords <- lapply(nodes, function(node) {
    point <- kb_xml_text(node, "./*[local-name()='Point']/*[local-name()='coordinates']")
    values <- suppressWarnings(as.numeric(strsplit(point, ",", fixed = TRUE)[[1L]]))
    values[1:2]
  })
  data.frame(
    id = vapply(nodes, xml2::xml_attr, character(1), attr = "id"),
    title = vapply(nodes, kb_xml_text, character(1), xpath = "./*[local-name()='name']"),
    longitude = vapply(coords, `[[`, numeric(1), 1L),
    latitude = vapply(coords, `[[`, numeric(1), 2L),
    location = kb_field(properties, "subjectGeographic"),
    photographer = kb_field(properties, "subjectCreatorName"),
    date = kb_field(properties, "subjectCreationDate"),
    type = kb_field(properties, "subjectGenre"),
    url = kb_https(kb_field(properties, "subjectLink")),
    thumbnail_url = kb_dsfl_image_url(kb_field(properties, "subjectThumbnailSrc"), ",150"),
    image_url = kb_dsfl_image_url(kb_field(properties, "subjectImageSrc"), "full"),
    stringsAsFactors = FALSE
  )
}

kb_dsfl_image_url <- function(url, size) {
  legacy <- "^https?://www\\.kb\\.dk/imageService/(?:[wh][0-9]+/)*(.+)\\.jpg$"
  convert <- grepl(legacy, url, perl = TRUE)
  if (any(convert)) {
    identifier <- sub(legacy, "\\1", url[convert], perl = TRUE)
    url[convert] <- paste0("https://kb-images.kb.dk/", identifier, "/full/",
                           size, "/0/native.jpg")
  }
  kb_https(url)
}
