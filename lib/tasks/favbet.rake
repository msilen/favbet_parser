namespace :favbet do
  namespace :import do

    desc 'Imports soccer lines'
    task soccer: :environment do
      provider = Providers::Favbet.new(:soccer)
      provider.bet_lines
    end

  end
end
