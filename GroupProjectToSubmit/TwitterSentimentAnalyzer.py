# -*- coding: utf-8 -*-
"""
Created on Wed Nov 25 16:55:16 2015

@author: Suffyan Asad
"""

import twitter
from pandas.io import sql
import MySQLdb
import pandas as pd
import string
import time
import json, requests

dbName = 'SongsDb'
tableName = 'SongRating'
countriesTableName = 'SongImpressions'
positiveWordsFile = 'positive-words.txt'
negativeneWordsFile = 'negative-words.txt'
puncuations = string.punctuation
pause = 5; """ Pause is needed to remain within limit of twitter API of 180
              searches in 15 minutes """
locationsCache = {}

def getPosNegWords():
    posWordsFile = open(positiveWordsFile)
    posWords = []
    
    for line in posWordsFile:
        if line != [] and line != '' and line[0] != ';' and len(line) > 0:
            posWords.append(line.strip())
    
    negWordsFile = open(negativeneWordsFile)
    negWords = []
    
    for line in negWordsFile:
        if line != [] and line != '' and line[0] != ';' and len(line) > 0:
            negWords.append(line.strip())
    
    return posWords, negWords

def getCountryFromGeoNames(string):
    string = string.lower()
    if string in locationsCache:
        return locationsCache[string]
    else:
        try:
            url = 'http://api.geonames.org/search?q=%s&maxRows=1&username=lustrousflame&type=json' % string
            resp = requests.get(url=url)
            country = None
            response = resp.json()
            if (response['totalResultsCount'] > 0):
                country = response['geonames'][0]['countryName']
    
            locationsCache[string] = country
            return country
        except:
            return None

def getTweets(searchString):
    
    CONSUMER_KEY = "UcJZnTOeXJbVOa4V9DcDTfSdc"
    CONSUMER_SECRET = "PoULMltNtzmN2junakqccVUjdZsOZJC3bPVKMS6fczzi03IsCI"
    OAUTH_TOKEN = "372890207-m34bYSL8PCNfXbKdlo3aNqDGs5UHqyPZa9hnypJG"
    OAUTH_TOKEN_SECRET = "yi47l51NYphODctREW627uhkFlUl0ScOtpkwEXNkgmGYJ"
    
    auth = twitter.oauth.OAuth(OAUTH_TOKEN,
                               OAUTH_TOKEN_SECRET,
                               CONSUMER_KEY,
                               CONSUMER_SECRET)
    
    twitter_api = twitter.Twitter(auth = auth)
    
    searches = 40
    
    results = twitter_api.search.tweets(q=searchString, count = searches)
    
    countries = []
    locations = [res['user']['location'].strip().split(',')[0] for res in results['statuses']]
    
    
    #print 'Tweets acquired, getting countries'
    for location in locations:
        country = getCountryFromGeoNames(location)
        if (country != None):
            countries.append(country)
    
    ones = [1] * len(countries)
    countriesDataFrame = pd.DataFrame(ones, countries, columns=['Impressions'])
    countriesDataFrame = countriesDataFrame.groupby(countriesDataFrame.index).sum()
        
    tweets = [status['text'].strip().lower() for status in results['statuses']]
    return tweets, countriesDataFrame

def getListMatchScore(tweetText, wordsToMatch, title):
    songTitle = title.lower();
    
    for char in puncuations:
        tweetText.replace(char, "")
    
    tweetText = tweetText.replace(songTitle, '')    
    words = tweetText.split(" ")
    words = [word for word in words if len(word) > 0]
    score = 0;
    for word in words:
        if (word in wordsToMatch):
            score += 1
    return score
    
def isRetweet(tweetText):
    for char in puncuations:
        tweetText.replace(char, "")
        
    words = tweetText.split(" ")
    
    for word in words:
        if (word == 'rt'):
            return 1
    return 0

def getSongsFromDatabase(dbName, tableName):
    connection = MySQLdb.connect(host='localhost', user='root', passwd='root', db=dbName)
    dataFrame = pd.read_sql("select * from %s;" % tableName, connection)    
    connection.close()
    return dataFrame

def saveInDb(songsDataFrame, tableName):
    connection = MySQLdb.connect(host='localhost', user='root', passwd='root', db=dbName)
    sql.write_frame(songsDataFrame, tableName, con=connection, if_exists='replace', flavor='mysql')
    connection.close()

def mainFunction():
    
    positveWords, negativeWords = getPosNegWords()
    
    songsDataFrame = getSongsFromDatabase(dbName, tableName)
    songsDataFrame['SearchString'] = songsDataFrame['Title'].map(str) + " " + songsDataFrame['Artist']
    
    countryImpressions = []
    
    searchStrings = songsDataFrame['SearchString'].values
    
    for index, searchString in enumerate(searchStrings):
        #tweets = getTweets(searchString)
        tweets, countries = getTweets(searchString)
        
        countries = countries.reset_index()
        countries.columns = ['Country', 'Impressions']
        
        countries['Year'] = [songsDataFrame['Year'].values[index]]*len(countries)
        countries['Title'] = [songsDataFrame['Title'].values[index]]*len(countries)
        countries['Artist'] = [songsDataFrame['Artist'].values[index]]*len(countries)
        #print countries
        columns = countries.columns.tolist()
        columns = columns[2:] + columns[:2]
        
        countries = countries.reindex(columns=columns)
        countryImpressions.append(countries)
        #print countries
        #print columns   
        
        positiveScore = 0
        negativeScore = 0
        positiveCount = 0
        negativeCount = 0
        retweetScore = 0
        for tweet in tweets:
            posScore = getListMatchScore(tweet, positveWords, songsDataFrame['Title'].values[index])
            negScore = getListMatchScore(tweet, negativeWords, songsDataFrame['Title'].values[index])
            positiveScore += posScore
            negativeScore += negScore
            if ((posScore - negScore) > 0):
                positiveCount += 1
            if ((posScore - negScore) < 0):
                negativeCount += 1
                
            retweetScore += isRetweet(tweet)
        
        songsDataFrame.loc[songsDataFrame.SearchString == searchString, 'PositiveScore'] = positiveScore
        songsDataFrame.loc[songsDataFrame.SearchString == searchString, 'NegativeScore'] = negativeScore
        songsDataFrame.loc[songsDataFrame.SearchString == searchString, 'PositiveTweets'] = positiveCount
        songsDataFrame.loc[songsDataFrame.SearchString == searchString, 'NegativeTweets'] = negativeCount
        songsDataFrame.loc[songsDataFrame.SearchString == searchString, 'Retweets'] = retweetScore
        
        print '%d %s - done' % (index, searchString) 
        time.sleep(pause)
    
    countryImpressions = pd.concat(countryImpressions)
    print countryImpressions
    
    songsDataFrame = songsDataFrame.drop('SearchString', axis=1)
    saveInDb(songsDataFrame, tableName)
    saveInDb(countryImpressions, countriesTableName)
    print "Twitter Analysis saved in Database %s in table %s" % (dbName, tableName)
    print "Country Impressions saved in Database %s in table %s" % (dbName, countriesTableName)
    
mainFunction()

