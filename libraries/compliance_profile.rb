# encoding: utf-8

require 'uri'

module Audit
  class ComplianceProfile
    attr_reader :owner, :name, :enabled, :connection
    attr_accessor :path

    def initialize(owner, name, enabled, path, connection)
      @owner = owner
      @name = name
      @enabled = enabled
      @path = path
      @connection = connection
    end

    def full_name
      "#{owner}/#{name}"
    end

    def to_s
      "Compliance profile #{full_name}"
    end

    def compliance_cache_path
      ::File.join(Chef::Config[:file_cache_path], 'compliance')
    end

    def tar_path
      return path if path
      ::File.join(compliance_cache_path, "#{owner}_#{name}.tgz")
    end

    def report_path
      ::File.join(compliance_cache_path, "#{owner}_#{name}_report.json")
    end

    def fetch
      return if path # will be fetched from other source during execute phase
      Chef::Log.info "Fetching #{self}"
      file = connection.fetch(self)
      move_profile_to_cache file
    end

    def move_profile_to_cache(file)
      path = tar_path
      Chef::Log.debug "Moving downloaded #{self} to cache destination: #{path}"
      case node['platform']
      when 'windows'
        # mv replaced due to Errno::EACCES:
        # https://bugs.ruby-lang.org/issues/10865
        FileUtils.cp(file.path, path) unless file.nil?
      else
        FileUtils.mv(file.path, path) unless file.nil?
      end
    end

    def execute
      puts 'PATH:'
      puts path
      puts 'TAR:'
      puts tar_path
      path ||= tar_path
      supported_schemes = %w{http https supermarket compliance chefserver}
      if !supported_schemes.include?(URI(path).scheme) && !::File.exist?(path)
        Chef::Log.warn "No such path! Skipping: #{path}"
        fail "Aborting since profile is not present here: #{path}" if run_context.node.audit.fail_if_not_present
        return
      end
      Chef::Log.info "Executing: #{path}"
      # TODO: flesh out inspec's report CLI interface,
      #       make this an execute[inspec check ...]
      output = quiet ? ::File::NULL : $stdout
      runner = ::Inspec::Runner.new('report' => true, 'format' => 'json-min', 'output' => output)
      runner.add_target(path, {})
      begin
        runner.run
      # TODO: weird exception, do we need that handling?
      rescue Chef::Exceptions::ValidationFailed => e
        log "INSPEC #{e}"
      end
      runner.report.to_json
    end
  end
end
