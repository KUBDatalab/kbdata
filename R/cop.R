kb_cop_editions <- function() {
  response <- kb_get(paste0(kb_portal, "/editions"))
  kb_cop_table(kb_array(kb_json(response)))
}

kb_cop_search <- function(edition, query = NULL, not_before = NULL,
                          not_after = NULL, page = 1L, page_size = 30L,
                          max_pages = 1L,
                          format = c("table", "json", "rss", "kml", "mods")) {
  format <- match.arg(format)
  edition <- kb_cop_id(edition)
  kb_check_string(query, "query", optional = TRUE)
  kb_check_integer(page_size, "page_size", max = 500L)
  dates <- kb_dates(not_before, not_after)

  if (format %in% c("table", "json")) {
    fetch_page <- function(page) {
      response <- kb_get(paste0(kb_portal, "/cop"), list(
        id = edition, query = query, before = dates$not_before,
        after = dates$not_after, page = page, itemsPerPage = page_size
      ))
      kb_rest_page(response, page, page_size)
    }
    table <- if (format == "table") kb_cop_table else NULL
    return(kb_collect(fetch_page, page, max_pages, table))
  }

  fetch_page <- function(page) {
    response <- kb_get(paste0(kb_syndication, edition), list(
      format = format, query = query, notBefore = dates$not_before,
      notAfter = dates$not_after, page = page, itemsPerPage = page_size
    ))
    kb_xml_page(response, format, page_size)
  }
  kb_collect(fetch_page, page, max_pages)
}

kb_cop_navigation <- function(edition, subject, format = c("table", "opml")) {
  format <- match.arg(format)
  edition <- sub("/(da|en)/$", "/", kb_cop_id(edition))
  kb_check_string(subject, "subject")
  if (!grepl("^(subject)?[0-9]+$", subject)) {
    stop("subject must be a COP subject ID such as 'subject841'.", call. = FALSE)
  }
  subject <- paste0("subject", sub("^subject", "", subject))
  response <- kb_get(paste0(kb_portal, "/navigation"),
                     list(identifier = edition, subjectId = subject))
  document <- kb_xml(response, "opml")
  if (format == "opml") {
    return(document)
  }
  nodes <- xml2::xml_find_all(document, ".//outline[@id]")
  data.frame(
    id = xml2::xml_attr(nodes, "id"),
    parent_id = vapply(nodes, function(node) {
      xml2::xml_attr(xml2::xml_parent(node), "id")
    }, character(1)),
    title = xml2::xml_attr(nodes, "text"),
    title_en = xml2::xml_attr(nodes, "text-en"),
    url = kb_https(xml2::xml_attr(nodes, "htmlUrl")),
    feed_url = kb_https(xml2::xml_attr(nodes, "xmlUrl")),
    stringsAsFactors = FALSE
  )
}

kb_cop_images <- function(id) {
  id <- kb_cop_id(id)
  if (!grepl("/object[0-9]+/", id)) {
    stop("id must be the COP path of an individual object.", call. = FALSE)
  }
  document <- kb_cop_search(id, page_size = 1L, format = "mods")[[1L]]
  nodes <- xml2::xml_find_all(document, paste0(
    "/*/*[local-name()='mods'] | ",
    "/*/*[local-name()='mods']//*[local-name()='relatedItem' and ",
    "(not(@type) or @type='constituent')]"
  ))
  identifier <- function(label) {
    vapply(nodes, kb_xml_text, character(1), xpath = sprintf(
      "./*[local-name()='identifier' and @displayLabel='%s']", label
    ))
  }
  images <- data.frame(
    title = vapply(nodes, kb_xml_text, character(1),
                   xpath = "./*[local-name()='titleInfo']/*[local-name()='title']"),
    iiif_info_url = kb_https(identifier("iiif")),
    image_url = kb_https(identifier("image")),
    thumbnail_url = kb_https(identifier("thumbnail")),
    stringsAsFactors = FALSE
  )
  key <- images$image_url
  key[is.na(key)] <- images$iiif_info_url[is.na(key)]
  key[is.na(key)] <- images$thumbnail_url[is.na(key)]
  images <- images[!is.na(key) & !duplicated(key), , drop = FALSE]
  rownames(images) <- NULL
  images
}

kb_rest_page <- function(response, page, page_size, aerial = FALSE) {
  records <- kb_array(kb_json(response))
  count <- kb_count(httr::headers(response)[["pagination-count"]])
  size <- kb_count(httr::headers(response)[["pagination-limit"]])
  if (is.na(size) || size == 0) {
    size <- page_size
  }
  if (aerial) {
    total <- count
    last <- if (is.na(count)) length(records) < size else page * size >= count
  } else {
    total <- kb_count(httr::headers(response)[["total"]])
    last <- if (is.na(count)) length(records) < size else page >= count
  }
  list(body = records, records = records, total = total, last = last)
}

kb_cop_id <- function(id) {
  kb_check_string(id, "edition")
  id <- sub("^https?://((www|digitalesamlinger|cop)\\.)?kb\\.dk/", "/", id)
  id <- sub("^/?cop/syndication/", "/", id)
  id <- paste0("/", gsub("^/+|/+$", "", id), "/")
  if (!grepl("^(/[-A-Za-z0-9_]+){5,}/$", id)) {
    stop("edition must be a COP identifier or a KB URL with that path.",
         call. = FALSE)
  }
  id
}

kb_cop_table <- function(records) {
  url <- kb_https(kb_field(records, "link"))
  id <- kb_field(records, "identifier")
  missing_id <- is.na(id)
  id[missing_id] <- sub("^https?://[^/]+", "", url[missing_id])
  data.frame(
    id = id,
    title = kb_field(records, "title"),
    description = kb_field(records, "description"),
    url = url,
    thumbnail_url = kb_https(kb_field(records, "thumbnailURI")),
    image_url = kb_https(kb_field(records, "imageURI")),
    stringsAsFactors = FALSE
  )
}
