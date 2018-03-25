require 'sequel'

Sequel::Model.plugin :json_serializer
Sequel.default_timezone = :utc

if ENV['thor_env'] != 'test'
  DB = Sequel.connect("sqlite://#{File.join(Dir.home, '.wakatime.sqlite')}")
else
  # Use a in memory db to have a nice clean testing bed.
  DB = Sequel.sqlite
end

DB.use_timestamp_timezones = false


require_relative './gitwakatime/version'
require_relative './gitwakatime/durations_calculator'
require_relative './gitwakatime/mapper'
require_relative './gitwakatime/query'
require_relative './gitwakatime/request'
require_relative './gitwakatime/request_builder'
require_relative './gitwakatime/timer'
require_relative './gitwakatime/log'
require_relative './gitwakatime/controller'
require_relative './gitwakatime/cli'


# It's a module :)
module GitWakaTime
  ##
  # Stores primary config and project information
  # Currently not thread safe.
  class Configuration
    attr_accessor :api_key, :log_level, :root, :project, :git

    def initialize
      self.api_key = nil
      self.log_level = :info
    end

    def user_name
      GitWakaTime.config.git.config('user.name')
    end

    def load_config_yaml
      yaml = YAML.load_file(File.join(Dir.home, '.wakatime.yml'))
      self.api_key = yaml[:api_key]
      self.log_level = yaml[:log_level]
    end

    def setup_local_db
      create_commits_table
      create_commited_files_table
      create_heartbeats_table
    end

    def create_commits_table
      DB.create_table? :commits do
        primary_key :id
        String :sha
        String :parent_sha
        String :project
        integer :time_in_seconds, default: 0
        datetime :date
        text :message
        String :author
      end
    end

    def create_commited_files_table
      DB.create_table? :commited_files do
        primary_key :id
        integer :commit_id
        String :dependent_sha
        DateTime :dependent_date
        integer :time_in_seconds, default: 0
        String :sha
        String :name
        String :entity
        String :project
        index :dependent_sha
        index :sha
      end
    end

    def create_heartbeats_table
      DB.create_table? :heartbeats do
        primary_key :id
        String :uuid
        DateTime :time
        integer :duration, default: 0
        String :entity
        String :type
        String :branch
        String :project
        index :uuid, unique: true
      end
    end
  end

  def self.config
    @configuration ||= Configuration.new
  end

  def self.configure
    yield(configuration) if block_given?
  end
end
