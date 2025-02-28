library(shiny)
library(gridlayout)
library(bslib)

# Here's a comment about this app
ui <- grid_page(
  layout = c(
    "header   header ",
    "cardDemo vbox   ",
    "sidebar  redPlot"
  ),
  row_sizes = c(
    "130px",
    "0.92fr",
    "1.08fr"
  ),
  col_sizes = c(
    "520px",
    "1fr"
  ),
  gap_size = "1rem",
  grid_card(
    area = "sidebar",
    card_body(
      sliderInput(
        inputId = "bins",
        label = "Number of Bins ",
        min = 12,
        max = 100,
        value = 30,
        width = "100%"
      ),
      actionButton(inputId = "redraw", label = "Redraw"),
      textInput(
        inputId = "bins2",
        label = "Text Input",
        value = ""
      )
    )
  ),
  grid_card_text(
    area = "header",
    content = "My demo app",
    alignment = "start",
    is_title = FALSE
  ),
  grid_card_plot(area = "redPlot"),
  grid_card(
    area = "cardDemo",
    card_header(h2("My Card header")),
    card_body(
      numericInput(
        inputId = "myNumericInput",
        label = "Numeric Input",
        value = 5
      )
    ),
    card_footer(
      textInput(
        inputId = "myTextInput",
        label = "Text Input",
        value = ""
      )
    )
  ),
  grid_card(
    area = "vbox",
    card_body(
      grid_container(
        layout = c(
          "a .",
          ". b"
        ),
        row_sizes = c(
          "1fr",
          "1fr"
        ),
        col_sizes = c(
          "1fr",
          "1fr"
        ),
        gap_size = "10px",
        grid_card(
          area = "a",
          card_body(
            value_box(
              title = "Look at me!",
              value = "My value",
              showcase = bsicons::bs_icon("database")
            )
          )
        ),
        grid_card(
          area = "b",
          card_body(
            value_box(
              title = "Look at me!",
              value = "My value",
              showcase = bsicons::bs_icon("chat-dots")
            )
          )
        )
      )
    )
  )
)

other_ui <- "hello there"

# Define server logic required to draw a histogram
server <- function(input, output) {

  output$redPlot <- renderPlot({
    print(input$bins2)
    print(input$bins)
    # draw the histogram with the specified number of bins
    hist(rnorm(100), col = 'orangered')
  })

  output$bluePlot <- renderPlot({
    # generate bins based on input$bins from ui.R
    x    <- faithful[, 2]
    bins <- seq(min(x), max(x), length.out = input$bins + 1)

    # draw the histogram with the specified number of bins
    hist(x, breaks = bins, col = 'steelblue', border = 'white')
  })

  observe({
    output$redPlot <- renderPlot({
      hist(rnorm(100), col = 'orangered')
    })
  }) %>% bindEvent(input$redraw)

  output$bluePlot2 <- renderPlot({
    #Plot code goes here
    plot(rnorm(100))
  })
}

shinyApp(ui, server)
