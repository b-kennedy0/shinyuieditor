library(shiny)
library(plotly)
library(gridlayout)
library(bslib)
library(DT)


ui <- grid_page(
  layout = c(
    "header  header   ",
    "sidebar timePlot2",
    "sidebar area3    "
  ),
  row_sizes = c(
    "100px",
    "1fr",
    "1.72fr"
  ),
  col_sizes = c(
    "455px",
    "1.41fr"
  ),
  gap_size = "10px",
  grid_card(
    area = "sidebar",
    card_header("Settings"),
    card_body(
      gap = "10px",
      max_height = "100px",
      min_height = "500px",
      checkboxGroupInput(
        inputId = "myCheckboxGroup",
        label = "City To Look At",
        choices = list("PM2.5" = "PM25", "pee" = "OZONE")
      ),
      radioButtons(
        inputId = "myRadioButtons",
        label = "A",
        choices = list("choice a" = "a", "myKey4" = "myValue4"),
        width = "50%"
      ),
      radioButtons(
        inputId = "myRadioButtons",
        label = "B",
        choices = list("choice a" = "a", "myKey4" = "myValue4"),
        width = "100%"
      )
    )
  ),
  grid_card_text(
    area = "header",
    content = "Geysers!",
    alignment = "start",
    is_title = FALSE
  ),
  grid_card_plot(area = "timePlot2"),
  grid_card(
    area = "area3",
    card_body(DTOutput(outputId = "myTable", width = "100%"))
  )
)


server <- function(input, output) {

  output$distPlot <- renderPlotly({
    # generate bins based on input$bins from ui.R
    plot_ly(x = ~ faithful[, 2], type = "histogram")
  })

  output$bluePlot <- renderPlot({
    # generate bins based on input$bins from ui.R
    x <- faithful[, 2]
    bins <- seq(min(x), max(x), length.out = input$bins + 1)

    # draw the histogram with the specified number of bins
    hist(x, breaks = bins, col = "steelblue", border = "white")
  })

  output$myTable <- renderDT({
    faithful
  })

  output$timePlot <- renderPlot({
    #Plot code goes here
    plot(rnorm(100))
  })

  output$timePlot2 <- renderPlot({
    #Plot code goes here
    plot(rnorm(100))
  })
}

shinyApp(ui, server)


