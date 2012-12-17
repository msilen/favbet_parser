#coding:utf-8
$LOAD_PATH.unshift File.expand_path("..",__FILE__)
require 'pry'
require 'open-uri'
require 'nokogiri'
require 'mechanize'
require 'json'
require 'base'
require 'favbet/soccer'

module Providers
  class Favbet < Base
    include Soccer
    TOURNAMENT_LIST_URL="https://www.favbet.com/bets/menu/"
    MAINPAGE_URL='https://www.favbet.com/en/bets/'

    def initialize(sport=:soccer)
      super(sport)
    end

    def bet_lines 
      initialize_agent
      get_lines
    end

    def initialize_agent
      @ajax_headers = { 'X-Requested-With' => 'XMLHttpRequest', 'Content-Type' => 'application/x-www-form-urlencoded; charset=UTF-8', 'Accept' => 'text/html, */*; q=0.01'}
      @agent=Mechanize.new
      begin
        page=@agent.get(MAINPAGE_URL) #получаем кукисы,etc.
      rescue Exception => e
        @logger.error("Error opening url #{MAINPAGE_URL}: #{e.message}")
        return false
      end
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


    def get_tournaments_ids
      tournament_id_list=[]#список id турниров для запроса через ajax
      tournament_list_hash=JSON.parse(@agent.get(TOURNAMENT_LIST_URL).body) #ajax get request
      if @sport==:soccer
        soccer_hash=tournament_list_hash['sports'][0]#хэш списка турниров по футболу со странами и лигами
        soccer_hash['countries'].each do |country|
          tournament_id_list << country['tournaments'].map{|e|e['tournament_id']}
        end
      end
      tournament_id_list.flatten
    end

  end
end

