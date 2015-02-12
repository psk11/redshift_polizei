module Models
  #
  # Model representing an export job
  #
  class ExportJob < ActiveRecord::Base
    # id                     :integer          not null, primary key
    # name                   :string(255)      not null
    # user_id                :integer          not null
    # success_email          :string(255)      null
    # failure_email          :string(255)      null
    # public                 :integer          not null
    # query                  :integer          not null
    # export_format          :string           not null
    # export_options         :json             not null

    belongs_to :user

    def enqueue(user, db_username, db_password, options={})
      Jobs::PolizeiExportJob.enqueue(self.id, user.id, {
        db: {
          connection_id: "redshift_#{Sinatra::Application.environment}",
          username: db_username,
          password: db_password,
          query: self.query
        },
        s3: {
          access_key_id: AWSConfig['access_key_id'],
          secret_access_key: AWSConfig['secret_access_key'],
          bucket: AWSConfig['export_bucket']
        },
        csv: {
          col_sep: self.export_options['delimiter'],
          return_headers: self.export_options['include_header']
        }
      }.merge(options))
    end

    def self.test(user, options={})
      Jobs::PolizeiExportJob.test(user.id, options)
    end

    def last3_runs
      export_runs(Jobs::PolizeiExportJob.last_runs(self.id, 3))
    end

    def runs_unfinished(user=nil)
      export_runs(Jobs::PolizeiExportJob.runs_unfinished(self.id, user.id))
    end

    def success_email_to
      "#{self.user.email}, #{self.success_email}"
    end

    def failure_email_to
      "#{self.user.email}, #{self.failure_email}"
    end

    private
      def export_runs(desmond_runs)
        desmond_runs.map { |r| ExportJobRun.new(r) }
      end

    class ExportJobRun
      def initialize(desmond_run)
        @run = desmond_run
        @datetime_format = '%F %T UTC'
      end

      def user
        Models::User.find(@run.user_id)
      end

      def completed_at
        @run.completed_at.strftime(@datetime_format)
      end

      def executed_at
        @run.executed_at.strftime(@datetime_format)
      end

      def queued_at
        @run.queued_at.strftime(@datetime_format)
      end

      def done?
        @run.done?
      end

      def failed?
        @run.failed?
      end

      def running?
        @run.running?
      end

      def queued?
        @run.queued?
      end
    end
  end
end
