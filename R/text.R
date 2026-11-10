kb_text_search <- function(query = NULL, collection = NULL, author = NULL,
                           category = NULL, page = 1L, page_size = 10L,
                           max_pages = 1L, format = c("table", "json"),
                           source = c("tekster", "portal")) {
  format <- match.arg(format)
  source <- match.arg(source)
  kb_check_string(query, "query", optional = TRUE)
  kb_check_string(collection, "collection", optional = TRUE)
  kb_check_string(author, "author", optional = TRUE)
  kb_check_integer(page_size, "page_size", max = 100L)
  if (!is.null(category)) {
    category <- match.arg(category, c("work", "volume", "leaf", "editorial"))
  }

  fetch_page <- if (source == "tekster") {
    function(page) kb_tekster_page(query, collection, author, category, page, page_size)
  } else {
    function(page) kb_solr_page(query, collection, author, category, page, page_size)
  }
  table <- if (format == "table") kb_text_table else NULL
  out <- kb_collect(fetch_page, page, max_pages, table)
  attr(out, "kb_source") <- source
  out
}

kb_text_get <- function(id, format = c("table", "json")) {
  format <- match.arg(format)
  kb_check_string(id, "id")
  if (!grepl("^[A-Za-z0-9_.:-]+$", id)) {
    stop("id must be a document ID from the Text Portal.", call. = FALSE)
  }
  url <- paste0(kb_tekster, "/", utils::URLencode(id, reserved = TRUE), ".json")
  data <- kb_json(kb_get(url))
  record <- data$response$document
  if (!is.list(record) || is.null(record$id)) {
    stop("KB returned an unexpected Text Portal document.", call. = FALSE)
  }
  if (format == "json") data else kb_text_table(list(record))
}

kb_adl_text <- function(document, id = NULL, format = c("xml", "text")) {
  format <- match.arg(format)
  kb_check_string(document, "document")
  kb_check_string(id, "id", optional = TRUE)
  document <- sub("^(adl/)?texts/", "", document)
  if (!grepl("^[A-Za-z0-9_-][A-Za-z0-9_.-]*\\.xml$", document)) {
    stop("document must be an ADL XML filename such as 'hcaeventyr01val.xml'.",
         call. = FALSE)
  }
  if (!is.null(id) && !grepl("^[[:alnum:]_.:-]+$", id)) {
    stop("id must be a TEI xml:id.", call. = FALSE)
  }

  url <- paste0(
    "https://raw.githubusercontent.com/kb-dk/public-adl-text-sources/master/texts/",
    document
  )
  xml <- kb_xml(kb_get(url), "TEI")
  if (is.null(id) && format == "xml") {
    return(xml)
  }
  xpath <- if (is.null(id)) {
    "/*/*[local-name()='text']"
  } else {
    sprintf("//*[@xml:id='%s']", id)
  }
  node <- xml2::xml_find_first(xml, xpath)
  if (inherits(node, "xml_missing")) {
    stop("The requested text element was not found in this ADL volume.",
         call. = FALSE)
  }
  if (format == "xml") node else xml2::xml_text(node, trim = TRUE)
}

kb_tekster_page <- function(query, collection, author, category, page, page_size) {
  params <- list(
    q = query, page = page, per_page = page_size,
    `f[subcollection_ssi][]` = collection,
    `f[author_name_ssim][]` = author
  )
  if (identical(category, "editorial")) {
    params[["f[is_editorial_ssi][]"]] <- "yes"
  } else {
    params[["f[type_ssi][]"]] <- category
  }
  data <- kb_json(kb_get(paste0(kb_tekster, ".json"), params))
  paging <- data$meta$pages
  total <- kb_count(paging$total_count)
  pages <- kb_count(paging$total_pages)
  if (is.na(total) || is.na(pages)) {
    stop("KB returned an unexpected Text Portal search response.", call. = FALSE)
  }
  records <- lapply(kb_array(data$data), function(item) {
    if (!is.list(item$attributes) || is.null(item$id)) {
      stop("KB returned a malformed Text Portal record.", call. = FALSE)
    }
    record <- item$attributes
    record$id <- item$id
    record
  })
  list(body = data, records = records, total = total, last = page >= pages)
}

kb_solr_page <- function(query, collection, author, category, page, page_size) {
  literal <- function(value) as.character(jsonlite::toJSON(value, auto_unbox = TRUE))
  terms <- c(
    if (!is.null(query)) paste0("(", query, ")"),
    if (!is.null(collection)) paste0("subcollection_ssi:", literal(collection)),
    if (!is.null(author)) paste0("author_name_tesim:", literal(author)),
    if (identical(category, "leaf")) "type_ssi:leaf"
      else if (!is.null(category)) paste0("cat_ssi:", category)
  )
  start <- (as.double(page) - 1) * page_size
  response <- kb_get(paste0(kb_portal, "/text"), list(
    q = if (length(terms)) paste(terms, collapse = " AND ") else "*:*",
    wt = "json", start = start, rows = page_size
  ))
  data <- kb_json(response)
  records <- kb_array(data$response$docs)
  total <- kb_count(data$response$numFound)
  offset <- kb_count(data$response$start)
  if (is.na(total) || is.na(offset)) {
    stop("KB returned an unexpected Solr search response.", call. = FALSE)
  }
  list(body = data, records = records, total = total,
       last = offset + length(records) >= total)
}

kb_text_table <- function(records) {
  id <- kb_field(records, "id")
  title <- kb_field(records, "work_title_tesim")
  volume <- kb_field(records, "volume_title_tesim")
  missing_title <- is.na(title)
  title[missing_title] <- volume[missing_title]
  authors <- kb_field(records, "author_nasim")
  author_key <- kb_field(records, "author_name_ssim")
  missing_author <- is.na(authors)
  authors[missing_author] <- author_key[missing_author]
  url <- id
  present <- !is.na(id)
  url[present] <- paste0(kb_tekster, "/", vapply(
    id[present], utils::URLencode, character(1), reserved = TRUE, USE.NAMES = FALSE
  ))
  data.frame(
    id = id,
    title = title,
    volume_title = volume,
    author = authors,
    author_key = author_key,
    collection = kb_field(records, "subcollection_ssi"),
    type = kb_field(records, "type_ssi"),
    category = kb_field(records, "cat_ssi"),
    publication_date = kb_field(records, "date_published_ssi"),
    text = kb_field(records, "text_tesim", " "),
    source_path = sub("#.*$", "", kb_field(records, "url_ssi")),
    xml_id = kb_field(records, "xmlid_ssi"),
    rights = kb_field(records, "copyright_ssi"),
    url = url,
    stringsAsFactors = FALSE
  )
}
