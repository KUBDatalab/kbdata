kb_dr_api <- "https://www.kb.dk/ds-api/bff/v1"
kb_dr_max_start <- 2000L
kb_dr_max_rows <- 5000L
kb_dr_timezone <- "Europe/Copenhagen"
kb_dr_fields <- c(
  "id", "title", "origin", "creator_affiliation_facet", "creator_affiliation",
  "startTime", "endTime", "duration_ms", "genre_facet", "genre", "description",
  "annotation"
)

kb_dr_search <- function(query = NULL, media = c("all", "radio", "tv"),
                         channel = NULL, genre = NULL, not_before = NULL,
                         not_after = NULL, sort = c("relevance", "newest", "oldest"),
                         page = 1L, page_size = 20L, max_pages = 1L,
                         format = c("table", "json")) {
  media <- match.arg(media)
  sort <- match.arg(sort)
  format <- match.arg(format)
  kb_check_integer(page_size, "page_size", max = kb_dr_max_rows)
  last_page <- floor(kb_dr_max_start / page_size) + 1L
  params <- kb_dr_query(query, media, channel, genre, not_before, not_after)
  params <- c(params, list(
    facet = "false", rows = page_size, fl = paste(kb_dr_fields, collapse = ","),
    sort = switch(sort, relevance = "score desc,id asc",
                  newest = "startTime desc,id asc", oldest = "startTime asc,id asc")
  ))

  client <- kb_dr_client()
  fetch_page <- function(page) {
    start <- (as.double(page) - 1) * page_size
    data <- client("/proxy/search/", c(params, list(start = start)))
    kb_dr_page(data, start, page_size)
  }
  table <- if (format == "table") kb_dr_table else NULL
  kb_collect(fetch_page, page, max_pages, table, last_page = last_page)
}

kb_dr_get <- function(id, format = c("table", "json")) {
  format <- match.arg(format)
  kb_check_string(id, "id")
  if (!grepl("^[A-Za-z0-9_:-][A-Za-z0-9_.:-]*$", id)) {
    stop("id must be a record ID from DR-arkivet.", call. = FALSE)
  }
  client <- kb_dr_client()
  path <- paste0("/proxy/record/", utils::URLencode(id, reserved = TRUE))
  data <- client(path, list(format = "JSON-LD"))
  if (!is.list(data) || !identical(data[["id"]], unname(id))) {
    stop("KB returned an unexpected DR-arkivet record.", call. = FALSE)
  }
  if (format == "json") {
    fields <- c(
      "@context", "@type", "id", "name", "alternateName", "description", "abstract",
      "publication", "startTime", "endTime", "duration", "genre", "annotation",
      "actor", "contributor", "creator", "director", "producer", "isPartOf",
      "keywords", "about", "inLanguage", "countryOfOrigin", "encodesCreativeWork",
      "videoQuality"
    )
    return(data[intersect(names(data), fields)])
  }

  service <- data[["publication"]][["publishedOn"]]
  origin <- switch(kb_string(data[["@type"]]), AudioObject = "ds.radio",
                   VideoObject = "ds.tv", NA_character_)
  kb_dr_table(list(list(
    id = id, title = data[["name"]], origin = origin,
    creator_affiliation_facet = service[["alternateName"]],
    creator_affiliation = service[["broadcastDisplayName"]],
    startTime = data[["startTime"]], endTime = data[["endTime"]],
    genre = data[["genre"]], description = data[["description"]],
    annotation = data[["annotation"]]
  )))
}

kb_dr_facets <- function(query = NULL, media = c("all", "radio", "tv"),
                         channel = NULL, genre = NULL, not_before = NULL,
                         not_after = NULL) {
  media <- match.arg(media)
  params <- kb_dr_query(query, media, channel, genre, not_before, not_after)
  client <- kb_dr_client()
  data <- client("/proxy/search/", c(params, list(
    facet = "true", rows = 0L, facet.limit = -1L
  )))
  result <- kb_dr_page(data, 0L, 0L)
  fields <- data[["facet_counts"]][["facet_fields"]]
  if (!is.list(fields)) {
    stop("KB returned an unexpected DR-arkivet facet response.", call. = FALSE)
  }
  labels <- c(channel = "creator_affiliation_facet", genre = "genre_facet",
              year = "temporal_start_year")
  tables <- lapply(names(labels), function(facet) {
    values <- fields[[labels[[facet]]]]
    if (length(values) %% 2L != 0L) {
      stop("KB returned an incomplete DR-arkivet facet count.", call. = FALSE)
    }
    terms <- seq_along(values) %% 2L == 1L
    data.frame(
      facet = rep(facet, sum(terms)),
      value = vapply(values[terms], as.character, character(1), USE.NAMES = FALSE),
      count = vapply(values[!terms], kb_count, numeric(1), USE.NAMES = FALSE),
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, tables)
  attr(out, "kb_total") <- result$total
  out
}

kb_dr_client <- function() {
  handle <- httr::handle("https://www.kb.dk")
  authenticated <- FALSE
  authenticate <- function() {
    kb_get(paste0(kb_dr_api, "/authenticate/"), handle = handle)
    authenticated <<- TRUE
  }
  function(path, query) {
    if (!authenticated) {
      authenticate()
    }
    kb_json(kb_get(paste0(kb_dr_api, path), query, handle, authenticate))
  }
}

kb_dr_query <- function(query, media, channel, genre, not_before, not_after) {
  kb_check_string(query, "query", optional = TRUE)
  dates <- kb_dates(not_before, not_after)
  filters <- c(
    if (media != "all") sprintf('origin:"ds.%s"', media),
    kb_dr_filter("creator_affiliation_facet", channel, "channel"),
    kb_dr_filter("genre_facet", genre, "genre")
  )
  if (!is.null(dates$not_before) || !is.null(dates$not_after)) {
    lower <- if (is.null(dates$not_before)) "*" else kb_dr_midnight(dates$not_before)
    upper <- if (is.null(dates$not_after)) "*]" else {
      paste0(kb_dr_midnight(as.Date(dates$not_after) + 1L), "}")
    }
    filters <- c(filters, sprintf("startTime:[%s TO %s", lower, upper))
  }
  c(list(q = if (is.null(query)) "*:*" else query),
    structure(as.list(filters), names = rep("fq", length(filters))))
}

kb_dr_filter <- function(field, values, name) {
  if (is.null(values)) {
    return(character())
  }
  if (!is.character(values) || anyNA(values) || any(!nzchar(trimws(values)))) {
    stop(sprintf("%s must contain non-empty character strings.", name), call. = FALSE)
  }
  if (!length(values)) {
    return(character())
  }
  terms <- vapply(unique(values), function(value) {
    paste0(field, ":", jsonlite::toJSON(value, auto_unbox = TRUE))
  }, character(1), USE.NAMES = FALSE)
  if (length(terms) == 1L) terms else paste0("(", paste(terms, collapse = " OR "), ")")
}

kb_dr_midnight <- function(date) {
  midnight <- as.POSIXct(as.character(date), format = "%Y-%m-%d", tz = kb_dr_timezone)
  format(midnight, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
}

kb_dr_page <- function(data, start, page_size) {
  response <- data[["response"]]
  if (!is.list(response)) {
    stop("KB returned an unexpected DR-arkivet search response.", call. = FALSE)
  }
  records <- kb_array(response[["docs"]])
  total <- kb_count(response[["numFound"]])
  offset <- kb_count(response[["start"]])
  if (is.na(total) || is.na(offset) || offset != start) {
    stop("KB returned invalid DR-arkivet pagination metadata.", call. = FALSE)
  }
  exact <- !identical(response[["numFoundExact"]], FALSE)
  if (exact && length(records) != min(page_size, max(0, total - start))) {
    stop("KB returned an incomplete DR-arkivet result page.", call. = FALSE)
  }
  list(body = data, records = records, total = total,
       last = length(records) < page_size || (exact && start + length(records) >= total))
}

kb_dr_table <- function(records) {
  id <- kb_field(records, "id")
  channel <- kb_field(records, "creator_affiliation_facet")
  genre <- kb_field(records, "genre_facet")
  missing_channel <- is.na(channel)
  missing_genre <- is.na(genre)
  channel[missing_channel] <- kb_field(records[missing_channel], "creator_affiliation")
  genre[missing_genre] <- kb_field(records[missing_genre], "genre")
  start_time <- as.POSIXct(kb_field(records, "startTime"),
                           format = "%Y-%m-%dT%H:%M:%OSZ", tz = "UTC")
  end_time <- as.POSIXct(kb_field(records, "endTime"),
                         format = "%Y-%m-%dT%H:%M:%OSZ", tz = "UTC")
  duration <- suppressWarnings(as.numeric(kb_field(records, "duration_ms"))) / 1000
  missing_duration <- is.na(duration)
  duration[missing_duration] <- as.numeric(difftime(
    end_time[missing_duration], start_time[missing_duration], units = "secs"
  ))
  url <- id
  present <- !is.na(id)
  if (any(present)) {
    url[present] <- paste0(
      "https://www.kb.dk/find-materiale/dr-arkivet/post/",
      vapply(id[present], utils::URLencode, character(1), reserved = TRUE,
             USE.NAMES = FALSE)
    )
  }
  data.frame(
    id = id, title = kb_field(records, "title"),
    media = sub("^ds\\.", "", kb_field(records, "origin")), channel = channel,
    broadcast_date = as.Date(start_time, tz = kb_dr_timezone),
    start_time = start_time, end_time = end_time, duration_seconds = duration,
    genre = genre, description = kb_field(records, "description"),
    annotation = kb_field(records, "annotation"), url = url,
    stringsAsFactors = FALSE
  )
}
