library(rworldmap)
library(shiny)
library(RMySQL)
library(ggplot2)
library(RColorBrewer)
library(reshape2)
library(scales)

n = 40
shinyServer(function(input, output, clientData, session){
  observe({
    year = input$Years;
    if (year != 'Summary')
    {
      titles = getSongsForYear(year);
    
      updateSelectInput(session, 'Title', choices = titles);
    }
    else
    {
      updateSelectInput(session, 'Title', choices = c("-"));
    }
  });
  
  output$mainPlot <- renderPlot(
    {
      year = input$Years;
      if (year != 'Summary')
      {
        title = input$Title;
        if (title != '')
        {
          songInfo = getSongInfo(title, year);
          if (nrow(songInfo) > 0)
          {
            songInfo$Title = NULL;
            headers <- names(songInfo);
            y <- as.numeric(as.vector(songInfo[1,]));
            plot = singleSongPlot(headers, y, "");
          }
        }
      }
      else
      {
        summary = yearlySummary();
      }
    }
  );
  
  output$secondaryPlot <- renderPlot(
    {
      year = input$Years;
      title = input$Title;
      if (year != 'Summary' && title != '')
      {
        plot = countryImpressionsPlot(title = title, year = year);
      }
    }
  );
  
  output$songRankings <- renderDataTable(
    {
      year = input$Years;
      if (year != 'Summary')
      {
        table = getSongsRankingByYear(year);
        table;
      }
    }
  );
  
  output$header1 <- renderUI({
      year = input$Years
      if (year != 'Summary')
      {
        if (input$Title == 'All Songs' || input$Title == '')
        {
          h2(sprintf("Summary for All Songs (%s)", input$Years));
        }
        else
        {
          h2(sprintf("Summary for '%s'", input$Title));
        }
      }
      else
      {
        h2("Score, Retweets over year")
      }
    });
  
  output$header2 <- renderUI({
    year = input$Years
    if (year != 'Summary')
    {
      h2("Worldwide Impressions");
    }
    else
    {
      h2("")
    }
  });
  
  output$header3 <- renderUI({
    year = input$Years
    if (year != 'Summary')
    {
      h3(sprintf("Twitter Score Based Ranking of Songs (Year %s)", year));
    }
  });
  
  output$summary1 <- renderPlot({
    plotStatsByAge();
  });
  
  output$summary2 <- renderPlot({
    plotRetweetsAgeCorrelation();
  });
  
  output$summary3 <- renderPlot({
    plotRetweetsPositiveScoreCorrelation()
  });
  
  output$plot4 <- renderPlot({
    allCountryImpressionsPlot()
  });
  
  output$summary5 <- renderDataTable({
    getAllCountryImpressions()
  })

})

getSongsForYear <- function(year){
  connection = dbConnect(MySQL(),
    user='root',
    password='root',
    host='localhost',
    dbname='SongsDb'
  )
  
  query = sprintf('select "All Songs" Song UNION ALL select CONCAT(Title) Song from SongRating where year = %s;', year);
  table = dbGetQuery(conn = connection, statement = query);
  dbDisconnect(connection);
  table;
}

getSongInfo <- function(title, year){
  connection = dbConnect(MySQL(),
                         user='root',
                         password='root',
                         host='localhost',
                         dbname='SongsDb'
  )
  query = sprintf('select Title, 
                  (PositiveTweets/40 * 100) `Positive Tweets (percent)`, 
                  (NegativeTweets/40 * 100) `Negative Tweets (percent)`, 
                  (Retweets/40 * 100) `Retweets (percent)`
                  from SongRating where year = %s and Title = "%s";', year, title);
  if (title == "All Songs")
  {
    query = sprintf('select "All Songs" as Title, 
                     (SUM(PositiveTweets)/ 800 *100) `Positive Tweets (percent)`, 
                     (SUM(NegativeTweets)/ 800 *100) `Negative Tweets (percent)`, 
                     (SUM(Retweets)/ 800 *100) `Retweets (percent)`
                    from SongRating where year = %s;', year);
  }
  table = dbGetQuery(conn = connection, statement = query);
  dbDisconnect(connection);
  table;
}

getSongsRankingByYear <- function(year){
  connection = dbConnect(MySQL(),
                         user='root',
                         password='root',
                         host='localhost',
                         dbname='SongsDb'
  )
  
  query = sprintf(
  'SELECT 
    @rank := @rank + 1 Rank,
    Title,
    Artist,
    Rank as RankInListing,
    PositiveScore - NegativeScore as Score,
    PositiveTweets,
    NegativeTweets,
    Retweets
    FROM 
    SongsDb.SongRating, (select @rank := 0)r
    where year = %s
    order by Score desc;', year)
  
  table = dbGetQuery(conn = connection, statement = query);
  dbDisconnect(connection);
  table;
}

singleSongPlot <- function(x, y, xlabel){
  dataFrame <- data.frame(y, x);
  plot = ggplot(data=dataFrame, aes(x=x, y=y, fill=x)) + geom_bar(stat='identity');
  plot = plot + labs(x=xlabel);
  plot = plot + geom_text(aes(label=sprintf('%.2f%%', y), y=(y - 0.5*y)));
  plot = plot + expand_limits(y=0)
  print(plot);
}

getCountryImpressions <- function(title, year){
  connection = dbConnect(MySQL(),
                         user='root',
                         password='root',
                         host='localhost',
                         dbname='SongsDb'
  )
  query = sprintf('
    select
    Country, 
    (Impressions / 40 * 100) `Impressions (percent)`
    from SongsDb.SongImpressions
    where Title = "%s" and Year = %s
  ', title, year);
  if (title == 'All Songs')
  {
    query = sprintf('
    select
    Country, 
    (Sum(Impressions) / 800 * 100) `Impressions (percent)`
    from SongsDb.SongImpressions
    where Year = %s
    group by Country
  ', year);
  }
  table = dbGetQuery(conn = connection, statement = query);
  dbDisconnect(connection);
  table;
}

countryImpressionsPlot <- function(title, year){
  colorPal <- brewer.pal(n = 7, name = 'Reds')
  countryImpressions = getCountryImpressions(title, year);
  if (nrow(countryImpressions) > 0){
    print (countryImpressions);
    sPDF <- joinCountryData2Map(countryImpressions, joinCode = "NAME", nameJoinColumn  = "Country")
    print(mapCountryData(sPDF, 
                         nameColumnToPlot = "Impressions (percent)", 
                         catMethod = "categorical", 
                         colourPalette = colorPal,
                         oceanCol = "LightBlue",
                         missingCountryCol = 'White',
                         mapTitle = 'Percent Worldwide Impressions',
                         borderCol = 'Black'))
  }
}

yearlySummary <- function(){
  query = "SELECT Year, 
           SUM(PositiveScore - NegativeScore) Score, 
           (Sum(Retweets)/800 * 100) Retweets
           FROM SongsDb.SongRating
           GROUP BY Year;";
  
  connection = dbConnect(MySQL(),
                         user='root',
                         password='root',
                         host='localhost',
                         dbname='SongsDb'
  )
  print (query);
  table = dbGetQuery(conn = connection, statement = query);
  dbDisconnect(connection);
  plotYearlySummary(table);
}

plotYearlySummary <- function(dataTable)
{
  dataTable = melt(dataTable, id='Year')
  print(dataTable);
  plot = ggplot(data = dataTable, aes(x = Year, y=value, group=variable, colour=variable)) + geom_line() + geom_point();
  print (plot)
}

getStatsByAge <- function()
{
  connection = dbConnect(MySQL(),
                         user='root',
                         password='root',
                         host='localhost',
                         dbname='SongsDb'
  )
  query = "
    select Age,
    sum(T.PositiveTweets)/800 * 100 PositiveTweets,
    sum(T.NegativeTweets)/800 * 100 NegativeTweets,
    sum(T.PositiveScore)/800 * 100 PositiveScore,
    sum(T.NegativeScore)/800 * 100 NegativeScore,
    sum(T.Retweets)/ 800 * 100 Retweets
    from
    (
    select 
    	(2015 - Year) Age, 
    	PositiveTweets, 
    	NegativeTweets, 
    	PositiveScore, 
    	NegativeScore, 
    	Retweets
    	from SongsDb.SongRating
    ) T
    group by T.Age;
  ";
  table = dbGetQuery(conn = connection, statement = query);
  dbDisconnect(connection);
  table
}

plotStatsByAge <- function()
{
  dataTable = getStatsByAge();
  print (dataTable);
  correlation = (cor(dataTable))
  dataTable = melt(dataTable, id="Age");
  print (dataTable);
  
  plot = ggplot(data = dataTable, aes(x = Age, y=value, group=variable, colour=variable)) + geom_line() + geom_point() + geom_text(aes(label=value), vjust=-0.6) + scale_x_continuous(breaks=pretty_breaks(n=9)) + scale_y_continuous(limits = c(0, 35));
  
  print (plot)
  print (correlation)
}

plotRetweetsAgeCorrelation <- function()
{
  dataTable = getStatsByAge();
  dataTable = dataTable[,c('Age', 'Retweets')]
  
  regression = lm(Retweets ~ Age, data=dataTable)
  xVal = as.vector(dataTable[,c('Age')])
  yVals = xVal * summary(regression)$coefficients[2,1];
  yVals = yVals + summary(regression)$coefficients[1,1];
  dataTable$Reg = yVals
  plot = ggplot(data = dataTable, aes(x = Age)) + geom_point(aes(y=Retweets, color="Retweets", size=2)) + geom_line(aes(y=Reg, color="Reg")) + scale_x_continuous(breaks=pretty_breaks(n=9)) + scale_y_continuous(limits = c(0, 35))
  print(plot)
}

plotRetweetsPositiveScoreCorrelation <- function()
{
  dataTable = getStatsByAge();
  dataTable = dataTable[,c('Age', 'PositiveScore')]
  
  regression = lm(PositiveScore ~ Age, data=dataTable)
  xVal = as.vector(dataTable[,c('Age')])
  yVals = xVal * summary(regression)$coefficients[2,1];
  yVals = yVals + summary(regression)$coefficients[1,1];
  dataTable$Reg = yVals
  plot = ggplot(data = dataTable, aes(x = Age)) + geom_point(aes(y=PositiveScore, color="PositiveScore", size=2)) + geom_line(aes(y=Reg, color="Reg")) + scale_x_continuous(breaks=pretty_breaks(n=9)) + scale_y_continuous(limits = c(0, 35))
  print(plot)
}

getAllCountryImpressions <- function(){
  connection = dbConnect(MySQL(),
                         user='root',
                         password='root',
                         host='localhost',
                         dbname='SongsDb'
  )

    query = '
    select
    Country, 
    Sum(Impressions) `Impressions`
    from SongsDb.SongImpressions
    group by Country
    order by Impressions desc';
    
  table = dbGetQuery(conn = connection, statement = query);
  dbDisconnect(connection);
  table;
}

allCountryImpressionsPlot <- function(){
  colorPal <- brewer.pal(n = 7, name = 'YlOrRd')
  countryImpressions = getAllCountryImpressions();
  if (nrow(countryImpressions) > 0){
    print (countryImpressions);
    sPDF <- joinCountryData2Map(countryImpressions, joinCode = "NAME", nameJoinColumn  = "Country")
    print(mapCountryData(sPDF, 
                         nameColumnToPlot = "Impressions", 
                         catMethod = "categorical", 
                         colourPalette = colorPal,
                         oceanCol = "LightBlue",
                         missingCountryCol = 'White',
                         mapTitle = 'Worldwide Impressions',
                         borderCol = 'Black'))
  }
}