#' Launch shinyuieditor server
#'
#' Spins up an instance of the `shinyuieditor` server for building new and
#' editing existing Shiny UIs. The console will be blocked while running the
#' editor.
#'
#'
#' @inheritParams httpuv::startServer
#' @param app_loc Path to directory containing Shiny app to be visually edited
#'   (only single-file apps using an `app.R` are supported.) If the
#'   provided location doesn't exist, or doesn't contain an app, the app will
#'   start in an interface to select from a series of starter templates which
#'   will then be written to the location specified.
#' @param shiny_background_port Port to launch the shiny app preview on.
#'   Typically not necessary to set manually.
#' @param app_preview Should a live version of the Shiny app being edited run
#'   and auto-show updates made? You may want to disable this if the app has
#'   long-running or processor intensive initialization steps.
#' @param show_logs Print status messages to the console?
#' @param show_preview_app_logs Should the logged output of the app preview be
#'   printed? Useful for debugging an app that's not working properly. These
#'   logs are already shown in the app-preview pane of the editor.
#' @param launch_browser Should the browser be automatically opened to the
#'   editor?
#' @param stop_on_browser_close Should the editor server end when the browser
#'   window is closed or is dormant for too long. Set this to false if you want
#'   to try running the app in a different browser or refreshing the browser
#'   etc..
#'
#' @export
#'
#'
#' @examples
#' if (FALSE) {
#'   # Start editor on a non-existing app directory to choose a starter template
#'   launch_editor(app_loc = "empty_directory/")
#'
#'   # You can control where the app runs just like a normal Shiny app.
#'   # This can be useful if you want to access it from a headless server
#'   launch_editor(
#'     app_loc = "my-app/",
#'     host = "0.0.0.0",
#'     port = 8888,
#'     launch_browser = FALSE,
#'     stop_on_browser_close = FALSE
#'   )
#' }
launch_editor <- function(app_loc,
                          host = "127.0.0.1",
                          port = httpuv::randomPort(),
                          shiny_background_port = httpuv::randomPort(),
                          app_preview = TRUE,
                          show_logs = TRUE,
                          show_preview_app_logs = TRUE,
                          launch_browser = interactive(),
                          stop_on_browser_close = TRUE) {
  write_log <- function(...) {
    if (show_logs) {
      cat(..., "\n", file = stderr())
    }
  }

  # Make sure environment will allow features to work properly
  check_for_url_issues()

  # ----------------------------------------------------------------------------
  # State variables to keep track of app location etc..
  # ----------------------------------------------------------------------------

  # Basic mode of server. Can either be "initializing" | "template-chooser" |
  # "editing-app". This is used to know what to do on close
  server_mode <- "initializing"

  # Validate that we're pointing to a directory. If the user has supplied a
  # direct file. E.g. a app.R or app.py file we should back up the app loc to
  # the parent location
  app_loc <- validate_app_loc(app_loc)
  
  # This checks to make sure we're working with a single-file app. It will give
  # a depreciation error if it detects multifile apps
  has_app <- check_for_app_file(app_loc)

  # ----------------------------------------------------------------------------
  # Initialize classes for controling app preview and polling for updates
  # ----------------------------------------------------------------------------

  # Object that will watch for changes to the app script
  file_change_watcher <- FileChangeWatcher(app_loc)

  # Empty function so variable can always be called even if the timeout hasn't
  # been initialized
  app_close_watcher <- watch_for_app_close(
    on_close = if (stop_on_browser_close) {
      function() {
        write_log("Editor window closed, stopping server")
        rlang::interrupt()
      }
    }
  )

  # Initialize app preview object for controlling background app preview
  app_preview_obj <- app_preview_runner$new(
    app_loc = app_loc,
    port = shiny_background_port,
    host = host,
    print_logs = show_preview_app_logs,
    logger = write_log,
    run_preview = app_preview
  )



  # ----------------------------------------------------------------------------
  # Main logic for responding to messages from the client. Messages have a path
  # used for routing and an optional payload. A method of responding is provided
  # with a send_msg callback
  # ----------------------------------------------------------------------------
  setup_msg_handlers <- function(send_msg) {
    send_app_info_to_client <- function() {
      tryCatch(
        {
          send_msg(
            "APP-SCRIPT-TEXT", 
            list(
              language = "R",
              app_script = get_script(fs::path(app_loc, "app.R"))
            )
          )
        },
        error = function(error) {
          send_msg(
            "BACKEND-ERROR",
            list(
              context = "Loading app scripts",
              msg = error$message
            )
          )
        }
      )
    }

    load_new_app <- function() {

      if (!has_app) {
        send_msg("TEMPLATE_CHOOSER", "USER-CHOICE")
        server_mode <<- "template-chooser"
        return()
      }

      write_log("=> Loading app ui and sending to ui editor")

      file_change_watcher$start_watching(
        on_update = function() {
          write_log("=> Sending user updated ui to editor")
          send_app_info_to_client()
        }
      )

      server_mode <<- "editing-app"

      # Let client know if it can request server positions etc..
      send_msg(
        "CHECKIN",
        list(
          server_aware = rstudioapi::isAvailable(),
          language = "R",
          app_preview = app_preview
        )
      )

      app_preview_obj$start_app()
      send_app_info_to_client()
    }

    # Handles message from client with new app info
    handle_new_ui_from_client <- function(update_payload) {

      updated_scripts <- list(app = update_payload$app)

      if (!has_app) {
        file_change_watcher$set_watched_files("app.R")
        has_app <<- TRUE
      }

      file_change_watcher$update_files(updated_scripts)

      # If we're coming from the server mode or a new app type, then we need to
      # load the new app as well
      if (identical(server_mode, "template-chooser")) {
        # Setup files
        load_new_app()
      }
    }

    # Return a callback that takes in a message and reacts to it
    function(msg) {
      write_log("Message from client", msg$path)
      switch(msg$path,
        "APP-PREVIEW-REQUEST" = {
          send_msg("APP-PREVIEW-STATUS", payload = "LOADING")
          app_preview_obj$set_listeners(
            on_ready = function() {
              # Once the background preview app is up and running, we can
              # send over the URL to the react app
              send_msg(
                "APP-PREVIEW-STATUS",
                payload = list(url = app_preview_obj$url)
              )
            },
            on_crash = function() {
              send_msg("APP-PREVIEW-CRASH", payload = "uh-oh")
            },
            on_logs = function(log_lines) {
              send_msg("APP-PREVIEW-LOGS", payload = log_lines)
            },
            on_starting_up = function() {
              send_msg("APP-PREVIEW-STATUS", payload = "LOADING")
            }
          )
        },
        "APP-PREVIEW-RESTART" = {
          app_preview_obj$restart()
        },
        "APP-PREVIEW-STOP" = {
          app_preview_obj$stop_app()
        },
        "READY-FOR-STATE" = {
          if (has_app) {
            file_change_watcher$set_watched_files("app.R")
          }
          load_new_app()
        },
        "UPDATED-APP" = {
          handle_new_ui_from_client(msg$payload)
        },
        "ENTERED-TEMPLATE-SELECTOR" = {
          write_log("Template chooser mode")
          server_mode <<- "template-chooser"
        },
        "SELECT-SERVER-CODE" = {
          select_server_code(
            locations = msg$payload$positions,
            app_loc = app_loc
          )
        },
        "INSERT-SNIPPET" = {
          insert_server_code(
            snippet = msg$payload$snippet,
            insert_at = msg$payload$insert_at,
            app_loc = app_loc
          )
        }
      )
    }
  }

  # Cleanup on closing of the server...
  on.exit({
    # Stop all the event listeners
    app_preview_obj$stop_app()
    file_change_watcher$cleanup()
    app_close_watcher$cleanup()

    if (server_mode == "template-chooser") {
      file_change_watcher$delete_files(delete_root = TRUE)
    }
  })

  # Let the user know that the ui editor is ready for them to use and optionally
  # open the browser to it for them
  announce_location_of_editor(port, launch_browser)

  # Main server startup - Runs in main process
  httpuv::runServer(
    host = host, port = port,
    app = list(
      onWSOpen = function(ws) {
        # Cancel any app close timeouts that may have been caused by the
        # user refreshing the page
        app_close_watcher$connection_opened()

        # Setup function to respond to client
        handle_incoming_msg <- setup_msg_handlers(
          send_msg = function(path, payload) {
            ws$send(format_outgoing_msg(path, payload))
          }
        )

        # The ws object is a WebSocket object
        ws$onMessage(function(binary, raw_msg) {

          # The messages all come over in binary blob format with a type and an
          # optional payload field and need to be converted before being passed
          # to the handler callback
          handle_incoming_msg(parse_incoming_msg(raw_msg))
        })

        ws$onClose(function() {
          # When the websocket connection closes we start the timer to check if
          # it's a reload or a proper-closing of the window
          app_close_watcher$connection_closed()
        })
      },
      staticPaths = list(
        "/" = httpuv::staticPath(
          system.file("editor/build", package = "shinyuieditor"),
          indexhtml = TRUE
        )
      )
    )
  )
}
