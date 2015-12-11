# -*- coding: utf-8 -*-
"""
Created on Wed Nov 25 17:33:27 2015

@author: Suffyan Asad

Scrapes Billboard for last 9 years, gets 20 of hot 100 songs and then saves the
song and the artist to MySQL Database. It drops the table if previously existed.
It requires a Database called SongsDb to exist. Creates a table of hot songs,
their rank, year, title and singer
"""

from bs4 import BeautifulSoup
import urllib2
from pandas.io import sql
import MySQLdb
import pandas as pd
import numpy as np

years = [2014, 2013, 2012, 2011, 2010, 2009, 2008, 2007, 2006]
num = 20
baseUrl = 'http://billboard.com/charts/year-end/%d/hot-100-songs'
dbName = 'SongsDb'
tableName = 'SongRating'

def GetTop25SongsList(year, num):
    
    url = baseUrl % year
    page = urllib2.urlopen(url)
    pageSoup = BeautifulSoup(page, 'lxml')
    songs = []
    listDivs = pageSoup.findAll('div', {'class' : 'row-primary'})[:num]
    
    for div in listDivs:
        title = div.find('h2').text.strip().title()
        singer = div.find('h3').text.strip()
        rank = div.find('span', {"class":"this-week"}).text.strip()
        songRecord = {'Year' : year, 
                      'Title' : title, 
                      'Artist' : singer, 
                      'Rank' : rank}
                      
        songs.append(songRecord)
        
    songsDataframe = pd.DataFrame(songs, columns = ['Year', 'Title', 'Artist', 'Rank'])
    songsDataframe['PositiveTweets'] = 0
    songsDataframe['NegativeTweets'] = 0
    songsDataframe['Retweets'] = 0
    return songsDataframe

def saveSongsInDb(songsDataFrame):
    connection = MySQLdb.connect(host='localhost', user='root', passwd='root', db=dbName)
    sql.write_frame(songsDataFrame, tableName, con=connection, if_exists='replace', flavor='mysql')
    connection.close()
    
songsDataFrame = pd.DataFrame()
for year in years:    
    frame = GetTop25SongsList(year, num)
    songsDataFrame = pd.concat([songsDataFrame, frame])
    print '%d - done' % year

print songsDataFrame
saveSongsInDb(songsDataFrame)
print "Songs saved in Database %s in table %s" % (dbName, tableName)
    









