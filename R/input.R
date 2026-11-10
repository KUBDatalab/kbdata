kb_check_string <- function(value, name, optional = FALSE) {
  if (optional && is.null(value)) {
    return(invisible(NULL))
  }
  if (!is.character(value) || length(value) != 1L || is.na(value) ||
      !nzchar(trimws(value))) {
    stop(sprintf("%s must be a non-empty character string.", name), call. = FALSE)
  }
  invisible(value)
}

kb_check_integer <- function(value, name, max = .Machine$integer.max,
                             infinite = FALSE) {
  valid <- is.numeric(value) && length(value) == 1L && !is.na(value) &&
    (is.finite(value) && value >= 1 && value <= max && value == floor(value) ||
       infinite && value == Inf)
  if (!valid) {
    requirement <- if (max < .Machine$integer.max) {
      paste("a whole number from 1 to", max)
    } else {
      "a positive whole number"
    }
    if (infinite) {
      requirement <- paste(requirement, "or Inf")
    }
    stop(sprintf("%s must be %s.", name, requirement), call. = FALSE)
  }
  invisible(value)
}

kb_dates <- function(not_before, not_after) {
  values <- list(not_before = not_before, not_after = not_after)
  for (name in names(values)) {
    date <- values[[name]]
    if (is.null(date)) {
      next
    }
    if (inherits(date, "Date")) {
      date <- as.character(date)
    }
    kb_check_string(date, name)
    parsed <- suppressWarnings(as.Date(date, format = "%Y-%m-%d"))
    if (is.na(parsed) || !identical(as.character(parsed), unname(date))) {
      stop(sprintf("%s must be a valid date in YYYY-MM-DD format.", name),
           call. = FALSE)
    }
    values[[name]] <- unname(date)
  }
  if (!is.null(values$not_before) && !is.null(values$not_after) &&
      values$not_before > values$not_after) {
    stop("not_before must be on or before not_after.", call. = FALSE)
  }
  values
}

kb_string <- function(value, sep = "; ") {
  value <- trimws(as.character(unlist(value, use.names = FALSE)))
  value <- value[!is.na(value) & nzchar(value)]
  if (length(value)) paste(value, collapse = sep) else NA_character_
}

kb_field <- function(records, name, sep = "; ") {
  vapply(records, function(record) kb_string(record[[name]], sep),
         character(1), USE.NAMES = FALSE)
}

kb_https <- function(url) {
  sub("^http://((?:[A-Za-z0-9-]+\\.)*kb\\.dk)(?=/|$)",
      "https://\\1", url, perl = TRUE)
}
