kb_portal <- "https://api.kb.dk/data/rest/api"
kb_syndication <- "https://www.kb.dk/cop/syndication"
kb_tekster <- "https://tekster.kb.dk/text"

kb_get <- function(url, query = list(), handle = NULL, reauthenticate = NULL) {
  query <- lapply(query, function(value) {
    if (is.numeric(value)) {
      format(value, trim = TRUE, scientific = FALSE, decimal.mark = ".")
    } else {
      value
    }
  })
  response <- httr::RETRY(
    "GET", url, query = query, handle = handle,
    httr::user_agent(paste0("kbdata/", utils::packageVersion("kbdata"))),
    httr::timeout(getOption("kbdata.timeout", 30)),
    times = 3, pause_cap = 4, quiet = TRUE,
    terminate_on = setdiff(400:599, c(429L, 502L, 503L, 504L))
  )
  if (httr::status_code(response) == 401L && !is.null(reauthenticate)) {
    reauthenticate()
    return(kb_get(url, query, handle = handle))
  }
  if (httr::http_error(response)) {
    hint <- if (identical(url, paste0(kb_portal, "/text"))) {
      ' Try source = "tekster" for the current Text Portal.'
    } else {
      ""
    }
    stop(sprintf("GET %s returned HTTP %s.%s",
                 url, httr::status_code(response), hint), call. = FALSE)
  }
  response
}

kb_json <- function(response) {
  json <- httr::content(response, as = "text", encoding = "UTF-8")
  tryCatch(
    jsonlite::fromJSON(json, simplifyVector = FALSE),
    error = function(error) {
      stop("KB returned an invalid JSON response.", call. = FALSE)
    }
  )
}

kb_xml <- function(response, root) {
  document <- tryCatch(
    xml2::read_xml(httr::content(response, as = "raw"), options = "NONET"),
    error = function(error) {
      stop("KB returned an invalid XML response.", call. = FALSE)
    }
  )
  if (!identical(xml2::xml_name(xml2::xml_root(document)), root)) {
    stop(sprintf("KB returned XML with an unexpected root. Expected <%s>.", root),
         call. = FALSE)
  }
  document
}

kb_array <- function(value) {
  if (!is.list(value) || !is.null(names(value)) ||
      !all(vapply(value, is.list, logical(1)))) {
    stop("KB returned an unexpected JSON record array.", call. = FALSE)
  }
  value
}

kb_count <- function(value) {
  if (length(value) != 1L) {
    return(NA_real_)
  }
  value <- suppressWarnings(as.numeric(value))
  if (!is.finite(value) || value < 0 || value != floor(value)) {
    return(NA_real_)
  }
  value
}

kb_collect <- function(fetch_page, page, max_pages, table = NULL, last_page = Inf) {
  kb_check_integer(page, "page", max = min(last_page, .Machine$integer.max))
  kb_check_integer(max_pages, "max_pages", infinite = TRUE)
  pages <- list()
  total <- NA_real_

  repeat {
    result <- fetch_page(page)
    if (length(pages) == 0L) {
      total <- result$total
    }
    pages[[length(pages) + 1L]] <- if (is.null(table)) {
      result$body
    } else {
      as.list(result$records)
    }
    if (length(result$records) == 0L || isTRUE(result$last) ||
        length(pages) >= max_pages) {
      break
    }
    if (page >= last_page) {
      warning("KB's pagination limit was reached. Narrow the search for further results.",
              call. = FALSE)
      break
    }
    page <- as.double(page) + 1
  }

  out <- if (is.null(table)) pages else table(unlist(pages, recursive = FALSE))
  attr(out, "kb_total") <- total
  attr(out, "kb_pages_fetched") <- length(pages)
  out
}

kb_xml_page <- function(response, format, page_size) {
  root <- switch(format, rss = "rss", kml = "kml", mods = "modsCollection")
  document <- kb_xml(response, root)
  container <- switch(
    format,
    rss = xml2::xml_find_first(document, "/rss/channel"),
    kml = xml2::xml_find_first(document, "/*/*[local-name()='Document']"),
    mods = xml2::xml_root(document)
  )
  if (inherits(container, "xml_missing")) {
    stop("KB returned a feed without a result container.", call. = FALSE)
  }
  records <- xml2::xml_find_all(container, switch(
    format, rss = "./item", kml = ".//*[local-name()='Placemark']",
    mods = "./*[local-name()='mods']"
  ))
  total <- kb_count(kb_xml_text(container, "./*[local-name()='totalResults']"))
  start <- kb_count(kb_xml_text(container, "./*[local-name()='startIndex']"))
  last <- if (is.na(total) || is.na(start)) {
    length(records) < page_size
  } else {
    start - 1 + length(records) >= total
  }
  list(body = document, records = records, total = total, last = last)
}

kb_xml_text <- function(node, xpath) {
  xml2::xml_text(xml2::xml_find_first(node, xpath), trim = TRUE)
}
