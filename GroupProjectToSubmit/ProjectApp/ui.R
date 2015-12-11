shinyUI(fluidPage(
  headerPanel("Popular Songs Over Time"),
  tabsetPanel(
    tabPanel("Stats",
             sidebarLayout(
               sidebarPanel(
                 selectInput('Years',
                             label = 'choose a year',
                             choices = list('Summary','2006', '2007', '2008', '2009','2010', '2011', '2012', '2013', '2014'),
                             selected = '2010'),
                 selectInput('Title',
                             label='Choose Title',
                             choices = list(''))
               ),
               mainPanel(
                 uiOutput("header1"),
                 plotOutput("mainPlot"),
                 uiOutput("header2"),
                 plotOutput("secondaryPlot"),
                 uiOutput("header3"),
                 dataTableOutput("songRankings")
               )
             )
  ),
  tabPanel("Summary",
      h2("Twitter scores by Song Age"),
      plotOutput("summary1"),
      h2("Regression: Age and Retweets percent"),
      plotOutput("summary2"),
      h2("Regression: Age and Positive tweets"),
      plotOutput("summary3"),
      h2("Worldwide Impressions"),
      plotOutput("plot4", height = '650px'),
      dataTableOutput("summary5")
    )
  )
))