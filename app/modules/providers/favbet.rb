#coding:utf-8
$LOAD_PATH.unshift File.expand_path("..",__FILE__)
require 'pry'
require 'open-uri'
require 'nokogiri'
require 'mechanize'
require 'json'
require 'base'
require 'yaml'
require 'event'

module Providers
  module FavBet
    class SoccerTournamentParser
      TOURNAMENT_LIST_URL="https://www.favbet.com/bets/menu/"
      MAINPAGE_URL='https://www.favbet.com/en/bets/'

      def initialize()
      end

      def bet_lines 
        initialize_agent
        get_lines
      end

      def initialize_agent
        @ajax_headers = { 'X-Requested-With' => 'XMLHttpRequest', 'Content-Type' => 'application/x-www-form-urlencoded; charset=UTF-8', 'Accept' => 'text/html, */*; q=0.01'}
        @agent=Mechanize.new
        page=@agent.get(MAINPAGE_URL) #получаем кукисы,etc.
      end

      def get_lines #запрашиваем линии по каждому турниру
        @tournament_id_list=get_tournaments_ids#список турниров для дальнейшего ajax запроса
        @tournament_id_list.each do |t_id|
          params = {'tournaments' => ({"tournaments"=>[t_id]}).to_json}
          response = @agent.post( 'https://www.favbet.com/bets/events/', params, @ajax_headers)
          tournament_hash=JSON.parse response.body
          parse_tournament(tournament_hash)
        end
      end

      def parse_tournament(tournament_hash)
        events=tournament_hash['markets'][0]['tournaments'][0]['events']
        league=tournament_hash['markets'][0]['tournaments'][0]['tournament_name']
        puts "====League #{league}===="
        events.each do |event|
          next if event['head_market'].empty?
          SoccerEvent.new(event,@agent)
        end
      end

      def get_tournaments_ids
        tournament_id_list=[]#список id турниров для запроса через ajax
        tournament_list_hash=JSON.parse(@agent.get(TOURNAMENT_LIST_URL).body) #ajax get request
        soccer_hash=tournament_list_hash['sports'][0]#хэш списка турниров по футболу со странами и лигами
        soccer_hash['countries'].each do |country|
          tournament_id_list << country['tournaments'].map{|e|e['tournament_id']}
        end
        tournament_id_list.flatten
      end


    end

  end
end

favbet_parser=Providers::FavBet::SoccerTournamentParser.new
favbet_parser.bet_lines
