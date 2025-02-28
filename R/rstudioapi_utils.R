# Convert 0-indexed script positions as returned by the javascript client to
# 1-indexed positions as used by the rstudioapi
client_pos_to_rstudioapi_pos <- function(position) {
  rstudioapi::document_position(
    row = position$row + 1,
    column = position$column + 1
  )
}

# Convert the format provided by treesitter/ the js client to one usable by the
# rstudio api for highlighting code on the server
client_loc_to_rstudioapi_range <- function(location) {

  # Convert positions to the 1-indexed format used by the rstudioapi
  selection_start <- client_pos_to_rstudioapi_pos(location$start)
  selection_end <- client_pos_to_rstudioapi_pos(location$end)

  rstudioapi::document_range(
    start = selection_start,
    end = selection_end
  )
}


#' Select the code for the given app location based on client-side locations
#'
#' @param locations Locations of the code to be selected in the client
#' @param app_loc Path to directory containing Shiny app to be visually edited
#' (either containing an `app.R` or both a `ui.R` and `server.R`).
#'
#' @keywords internal
select_server_code <- function(locations, app_loc) {

  # Make sure the server-containing script is the main active file it's
  # in the right file incase the user has navigated away

  ensure_server_script_open(app_loc = app_loc)
  ranges <- lapply(
    X = locations,
    FUN = client_loc_to_rstudioapi_range
  )
  rstudioapi::setSelectionRanges(ranges = ranges)
}

#' Insert code into the server script at the given location
#' @param snippet Code to be inserted
#' @param insert_at Location to insert the code at
#' @param app_loc Path to directory containing Shiny app to be visually edited
#' (either containing an `app.R` or both a `ui.R` and `server.R`).
#' @keywords internal
insert_server_code <- function(snippet, insert_at, app_loc) {
  ensure_server_script_open(app_loc = app_loc)

  # Remove any vscode snippet related syntax from the snippet as it's not
  # supported in rstudio
  snippet <- gsub("\\$[0-9]+", "", snippet)

  rstudioapi::insertText(
    location = client_pos_to_rstudioapi_pos(insert_at),
    text = snippet
  )

  # Save new code so it's reflected in the Ui editor/ preview
  rstudioapi::documentSave()
}

ensure_server_script_open <- function(app_loc) {
  rstudioapi::navigateToFile(
    file = fs::path(app_loc, "app.R")
  )
}
