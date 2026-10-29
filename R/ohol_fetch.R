# ==========================================================
# Read every life of one OHOL player from oholcurse.com.
# No login needed. The player can be given as a leaderboard,
# curse or character name, the player page URL, or the hash.
# ==========================================================
library(httr2)
library(rvest)
library(xml2)
library(jsonlite)
library(dplyr)
library(lubridate)

OHOL_BASE <- "https://oholcurse.com"
OHOL_UA   <- "Mozilla/5.0 (ohol-stats script)"
WEEKDAYS  <- c("Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday")

# ---------- Talking to the website ----------
# Livewire needs the same cookies for every call, so keep one cookie file
ohol_session <- function() list(cookies = tempfile(fileext = ".txt"))

# Open a page. Return the CSRF token, the Livewire snapshot of the component
# holding the element with id = marker_id, and the parsed page.
.ohol_page <- function(sess, path, marker_id) {
  url <- paste0(OHOL_BASE, path)
  resp <- request(url) %>%
    req_user_agent(OHOL_UA) %>%
    req_cookie_preferences(path = sess$cookies) %>%
    req_perform()
  doc <- read_html(resp_body_string(resp))
  node <- xml_find_first(
    doc,
    sprintf("//*[@id='%s']/ancestor::*[@*[name()='wire:snapshot']][1]", marker_id)
  )
  if (inherits(node, "xml_missing")) {
    stop("Page layout not recognised. The website may have changed.")
  }
  list(
    url      = url,
    doc      = doc,
    token    = html_attr(html_element(doc, "meta[name=csrf-token]"), "content"),
    snapshot = xml_attrs(node)[["wire:snapshot"]]
  )
}

# Send one Livewire update and return the component response
.ohol_call <- function(sess, page, snapshot, updates, method, params = list()) {
  if (length(updates) == 0) updates <- setNames(list(), character(0))  # sends {}
  body <- list(
    `_token` = page$token,
    components = list(list(
      snapshot = snapshot,
      updates  = updates,
      calls    = list(list(path = "", method = method, params = params))
    ))
  )
  resp <- request(paste0(OHOL_BASE, "/livewire/update")) %>%
    req_user_agent(OHOL_UA) %>%
    req_cookie_preferences(path = sess$cookies) %>%
    req_headers(`X-Livewire` = "", Referer = page$url) %>%
    req_body_json(body, auto_unbox = TRUE) %>%
    req_timeout(120) %>%
    req_perform()
  resp_body_json(resp)$components[[1]]
}

# ---------- Finding a player ----------
# Search like the box on the oholcurse home page.
# Tries leaderboard name, then curse name, then character name.
# Returns one row per player found.
search_players <- function(query, sess = ohol_session()) {
  filters <- c(leaderboard = "leaderboard_name", curse_name = "curse_name", character_name = "name")
  home <- .ohol_page(sess, "/", "profileSearch")

  for (flt in names(filters)) {
    snap1 <- .ohol_call(sess, home, home$snapshot, list(), "setSearchFilter", list(flt))$snapshot
    snap2 <- .ohol_call(sess, home, snap1, list(query = query), "search")$snapshot
    results <- fromJSON(snap2, simplifyVector = FALSE)$data$results[[1]]
    if (length(results) == 0) next

    found <- bind_rows(lapply(results, function(r) {
      rec  <- if (is.null(names(r))) r[[1]] else r
      hash <- rec$player_hash
      if (is.null(hash) && !is.null(rec$character)) hash <- rec$character[[1]]$player_hash
      if (is.null(hash)) return(NULL)
      nm <- rec[[filters[[flt]]]]
      tibble(found_by = flt, name = if (is.null(nm)) "" else nm, hash = hash)
    }))
    if (nrow(found) == 0) next

    exact <- found %>% filter(tolower(trimws(name)) == tolower(trimws(query)))
    if (nrow(exact) > 0) found <- exact
    return(distinct(found, hash, .keep_all = TRUE))
  }
  tibble(found_by = character(), name = character(), hash = character())
}

# Accept a URL, a hash, or a name
find_player_hash <- function(player, sess = ohol_session()) {
  h <- regmatches(player, regexpr("[0-9a-fA-F]{40}", player))
  if (length(h) == 1) return(tolower(h))

  hits <- search_players(player, sess)
  if (nrow(hits) == 0) {
    stop('No player found for "', player, '". Check the spelling on oholcurse.com.', call. = FALSE)
  }
  if (nrow(hits) > 1) {
    print(as.data.frame(hits))
    stop('Several players match "', player,
         '". Use the full name, or one of the hashes above.', call. = FALSE)
  }
  message("Found ", hits$name, " by ", gsub("_", " ", hits$found_by))
  hits$hash
}

# ---------- Reading lives ----------
is_donkey_town <- function(location) {
  x <- suppressWarnings(as.numeric(trimws(sub("/.*$", "", location))))
  !is.na(x) & x <= -1e8
}

# Turn the lives table HTML into a data frame
.ohol_parse_table <- function(html, tz) {
  tab <- read_html(html) %>%
    html_element("table") %>%
    html_table(convert = FALSE)

  names(tab) <- trimws(names(tab))
  tab <- tab %>% mutate(across(everything(), ~ trimws(gsub("\\s+", " ", .x))))

  tab %>%
    rename(FullName = Name) %>%
    transmute(
      Name      = sub(" .*$", "", FullName),
      Surname   = ifelse(grepl(" ", FullName), sub("^[^ ]+ ", "", FullName), NA_character_),
      `Life ID` = as.integer(`Life ID`),
      Age       = as.numeric(Age),
      Sex       = Gender,
      Location  = Location,
      # Deaths by another player show as killer_<their life ID>
      `Died to` = sub("^killer_\\d+$", "killer", `Died to`),
      # Without login the site shows UTC, so convert to local time
      Died      = with_tz(ymd_hms(Died, tz = "UTC"), tz)
    ) %>%
    mutate(
      Born           = round_date(Died - dseconds(Age * 60), "second"),  # 1 year of age = 1 minute
      Date           = format(Born, "%Y-%m-%d"),
      Month          = format(Born, "%Y-%m"),
      Day            = WEEKDAYS[wday(Born, week_start = 1)],
      `Online Time`  = format(Born, "%H:%M:%S"),
      `Offline Time` = format(Died, "%H:%M:%S"),
      # Donkey Town sits far to the west, around x = -200,000,000.
      # The normal world stays within about a million.
      `Donkey Town`  = is_donkey_town(Location)
    ) %>%
    select(Date, Month, Day, Name, Surname, `Life ID`, Age, Sex, Location,
           `Died to`, Born, Died, `Online Time`, `Offline Time`, `Donkey Town`)
}

# player can be a name, the player page URL, or the hash
fetch_ohol_lives <- function(player, tz = Sys.timezone(), order = "desc") {
  sess <- ohol_session()
  hash <- find_player_hash(player, sess)

  # Open the lives page, then do what the PER PAGE = All menu does
  page <- .ohol_page(sess, paste0("/player/lives/", hash), "take")
  player_name <- trimws(sub("^.*Lives for ", "", html_text(html_element(page$doc, "title"))))
  comp <- .ohol_call(sess, page, page$snapshot,
                     list(take = "99999", order = order), "updateLimit")

  out <- .ohol_parse_table(comp$effects$html, tz)
  attr(out, "player") <- player_name
  message("Read ", nrow(out), " lives for ", player_name)
  out
}
