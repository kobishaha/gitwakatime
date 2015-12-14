require 'benchmark'
require 'colorize'

module GitWakaTime
  # Integrates the nested hash from mapper with heartbeats api
  class Query
    def initialize(range, project)
      @start_at = range.start_at
      @end_at = range.end_at
      @project = project
      @requests = RequestBuilder.new(@start_at, @end_at).call
      @heartbeats = args[:heartbeats] || []
      @session     = Wakatime::Session.new(api_key: GitWakaTime.config.api_key)
      @client      = Wakatime::Client.new(@session)
    end

    def load_heartbeats(params)
      unless cached?
        Log.new "Gettting heartbeats #{@args[:date]}".red
        time = Benchmark.realtime do
          @heartbeats = @client.heartbeats(@args)
        end

        Log.new "API took #{time}s"
        persist_heartbeats_localy(@heartbeats)
      end
      true
    end


    def call
      heartbeats = []
      @requests.each do |params|
        heartbeats << load_heartbeats
      end

      Durations.new(
        heartbeats: heartbeats.where('duration <= 0')
      ).heartbeats_to_durations

      heartbeats.where(project: @project).all
    end

    private

    def cached?
      max_local_timetamp = Heartbeat.max(:time)
      return false if max_local_timetamp.nil?
      @max_local_timetamp ||= (Time.parse(max_local_timetamp))

      @args[:date].to_date < @max_local_timetamp.to_date
    end

    def heartbeats
      Heartbeat.where(
        'time >= ? and time <= ? ', @start_at, @end_at
      )
    end
  end
end
