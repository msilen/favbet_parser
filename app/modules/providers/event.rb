module Providers
  module FavBet
    class SoccerEvent
      ADDITIONAL_EVENTS_URL='https://www.favbet.com/bets/events/'
      attr_reader :home_team,:away_team,:date,:sport

      def initialize(event,agent)
        @sport="Soccer"
        @bets=[]
        @agent=agent
        parse_event_hash(event)
      end

      def parse_event_hash(event)
        create_headmarket_bets(event)
        get_additional_lines(event['event_id'])
        puts "#{home_team} - #{@away_team} at #{Time.at @date}, 1 #{@bets[0].koef} X #{@bets[1].koef} 2 #{@bets[2].koef}"
      end

      def create_headmarket_bets(event)
        outcomes_arr=event['head_market']['outcomes']#основная линия 1x2 #headmarket otdelny method
        @home_team=outcomes_arr[0]['outcome_name']
        @away_team=outcomes_arr[2]['outcome_name']
        @date=event['event_dt']

        home_team_koef=outcomes_arr[0]['outcome_coef']
        draw_coef=outcomes_arr[1]['outcome_coef']
        away_team_koef=outcomes_arr[2]['outcome_coef']

        create_bookmaker_team(home_team)
        create_bookmaker_team(away_team)

        @bets << SoccerBet.new("event_id",0,"1",nil,home_team_koef)
        @bets << SoccerBet.new("event_id",0,"X",nil,draw_coef)
        @bets << SoccerBet.new("event_id",0,"2",nil,away_team_koef)
      end

      def create_bookmaker_team(name)
        name
      end

      def get_additional_lines(event_id)
        page = @agent.get(ADDITIONAL_EVENTS_URL + event_id.to_s) 
        data = JSON.parse page.body
        times = data['result_types']#hash['result_types'] 0-full time;1 - first half;2 - 2nd half
        times.each do |time| #time-хэш исходов на промежуток времени
          parse_time(time)
        end
      end

      #-----time parser----
      def parse_time(time)
        time_code=set_period(time)#код отрезка времени
        create_additional_bets(time['market_groups'],time_code)
      end

      def create_additional_bets(market_groups,time_code)# market_group группа ставок одного типа
        #разбираю класс soccerevent, т.к перешел ко 2му событию, нужен вывод класса
        market_groups.each do |mg|
          mname=mg['market_name']
          next if ["Half with most goals 3 way","To Win Either Half","First Team to score","Last Team to score","To Win To Nil", "Not To Lose And Over 2.5 Goals", "To Win And Over 2.5 Goals", "Goal scored in both halves", "To Win Both Halves", "To Win From Behind", "Leading at halftime and not to win", "HT/FT","Both Teams To Score Under 1.5 Goals","Both Teams To Score Over 1.5 Goals","1st Half Over 0.5 and 2nd Half Over 0.5", "Time of first goal","Correct Score", "How many goals will be scored","Draw and Total Under 2.5","Draw and Total Over 2.5","2 or 3 goals in match"].include? mname
          next if ["to score first goal and will win the match","to win by 1 goal or Draw","not to lose and Total Under 2.5", "to win by 1 goal", "to win and Total Under 2.5","to win by 2 goals","First goal","Last goal"].any?{|str|mname.include?(str)}

          mg['markets'].each do |market|
            outcomes=market['outcomes']
            outcomes.each_with_index do |o,i|
              binding.pry unless outcome_code(mname,o['outcome_name'],i,time_code)
              @bets << SoccerBet.new("event_id", time_code,
              outcome_code(mname,o['outcome_name'],i,time_code),
              value_code(mname,o,i),o['outcome_coef'])
            end
          end
        end
      end

      def get_value_from_string_with_parenthesis(string)
        string.scan(/\(([-+0123456789.]+)\)/).first.first.to_f
      end

      def strip_parentesis_from_string(string)
        string.scan(/(.+)\([-+0123456789.]+\)/).first.first.strip
      end

      def value_code(market_name,outcome,index)
        nilnames=["Double chance","Draw no bet","Both teams to score", "Odd/even score","Money Line","Match winner","Penalty in the match?"," Red card"]
        to_set_value_names=["Spread","Over/Under","Over/Under (team)","Yellow card handicap"]
        #строка94 проверяю почему не совпадает dparam1 , индекс =2 и не совпадают имена
        if nilnames.include? market_name
          return nil
        elsif to_set_value_names.include? market_name
          name_value=get_value_from_string_with_parenthesis(outcome['outcome_name'])
          binding.pry if market_name=="Yellow card handicap"
          binding.pry unless name_value

          if ["Over/Under","Over/Under (team)"].include? market_name
            param_value=outcome["outcome_dparam1"]
          else
            param_value=outcome["outcome_dparam#{index+1}"]#index с 0
          end

          if param_value==name_value
            return param_value
          else
            binding.pry
          end
        else
          binding.pry
        end
      end

      #bet_variation
      def outcome_code(market_name,bet_name,index, time_code)#index для определения home_team или away_team
        outcomes={"1X" => "1X","X2"=> "X2","12"=> "12"}
        market_codes={"Draw no bet" => ["DNB1","DNB2"],"Spread" => ["F1","F2"],"Match winner" => ["ML1","ML2"],"Yellow card handicap"=> ["YC_F1","YC_F2"]}
        #желт.карточки с гандикапом
        codes_from_outcome_with_parenthesis={"Over" => "TO", "Under"=> "TU"}
        if outcomes[bet_name]
          outcomes[bet_name]
        elsif market_codes[market_name]
          market_codes[market_name][index]
        elsif market_name=="Over/Under"
          outcome_name=strip_parentesis_from_string(bet_name)
          codes_from_outcome_with_parenthesis[outcome_name]
        elsif market_name=="Over/Under (team)"
          codeindex=["Over","Under"].find_index{|e|bet_name[e]}
          ["I#{index+1}TO","I#{index+1}TU"][codeindex]
        elsif ["Both teams to score","Odd/even score"].include? market_name
          {"Yes" => "BTS_Y","No" => "BTS_N","Odd"=> "ODD","Even"=> "EVEN"}[bet_name]
        elsif (time_code !=0)&&(market_name=="Money Line")
          money_line_codes=["1", "X","2"]#возвращаем по индексу 
          money_line_codes[index]
        elsif market_name=="Penalty in the match?"
          {"Yes" => "PEN_Y", "No" => "PEN_N"}[bet_name]
        elsif market_name==" Red card"
          {"Yes" => "RC_Y", "No" => "RC_N"}[bet_name]
        else
          binding.pry
        end
      end

      def set_period(time)
        determine_period={['Match (With ET)',0] => (-1),['Full Time',1] => 0,['1st Half',7] => 1, ['2nd Half',8] => 2} #определяем период по названию и result_type_id
        period=determine_period.values_at([time['result_type_name'],time['result_type_id']]).first
        binding.pry unless period
        raise 'unexpected period' unless period
        period
      end

      def sport
        "Soccer"
      end
    end

    class SoccerBet
      attr_reader :bookmaker_event, :period, :bet_variation, :value, :koef

      def initialize(bookmaker_event,period,bet_variation,value,koef)
        @bookmaker_event,@period,@bet_variation,@value,@koef=bookmaker_event,period,bet_variation,value,koef
      end
    end
  end
end
