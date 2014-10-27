require 'merlin'
require 'logger'
require 'erubis'
require 'fileutils'
require 'open3'
require 'merlin/logstub'

#TODO make template inflation and checking files for content changes multithreaded
#TODO debounce events if configured, so we dont constantly emit configs
#TODO support changes to the static assets as well

module Merlin
  class Emitter
    include Logstub
    attr_accessor :templates, :destination, :check_cmd, :commit_cmd

    def initialize(templates,destination,check_cmd = nil, commit_cmd = nil, logger = nil)
      @check_cmd, @commit_cmd = check_cmd, commit_cmd
      # ensure directory is a thing
      dest = File.stat(destination)
      raise "#{destination} not a directory" unless dest.directory?
      raise "#{destination} not a writable" unless dest.writable?
      @destination = destination
      #ensure templates are readable
      unreadable = templates.keys.reject{|t| File.readable? t}
      raise "Unable to read templates: #{unreadable.inspect}" unless unreadable.empty?
      @templates = templates
      @logger = logger
    end

    def emit data
      # inflate the templates
      files = templates.map do |template,target|
        begin
          logger.info "Templating #{template}"
          input = File.read(template)
          erb = Erubis::Eruby.new(input)
          #TODO can we create a custom binding that only has variables we want to be scoped in it?
          output = erb.result(binding)
        rescue => e
          logger.error "Error templating #{template}: #{e.message}"
          raise e
        end
        [target,output]
      end
      # map template name to new output
      target_output = Hash[files]
      # write files out targets if they have changed
      updated_targets = target_output.map do |target,output|
        target = File.join(destination,target)
        og_hash = if File.readable? target
            Digest::SHA256.file(target).hexdigest
          else
            "none"
          end
        new_hash = Digest::SHA256.hexdigest(output)
        logger.debug "#{target} SHA256: #{og_hash}, new contents: #{new_hash}"
        if og_hash == new_hash
          logger.info "No change to #{target}"
          nil
        else
          if og_hash != "none"
            backup = "#{target}.bak"
            logger.debug "Copying #{target} to #{backup}"
            FileUtils.cp target, backup
          end
          logger.info "Writing #{target}"
          File.open(target,'w') { |f| f.write(output) }
          {:file => target, :backup => backup}
        end
      end.compact

      return _check_and_commit updated_targets
    end

    private
    def _check_and_commit updated_targets
      success = true
      failed_command = nil
      begin
        unless updated_targets.empty?
          {:check => check_cmd, :commit => commit_cmd}.each do |type,cmd|
            if cmd.nil?
              logger.info "No #{type} command specified, skipping check"
            else
              logger.info "Running #{type} command: #{cmd}"
              begin
                res = Open3.popen2e(cmd) do |stdin, output, th|
                  stdin.close
                  pid = th.pid
                  logger.debug "Started pid #{pid}"
                  output.each {|l| logger.debug l.strip }
                  status = th.value
                  logger.debug "Process exited: #{status.to_s}"
                  status
                end
                if res.success?
                  logger.info "#{type.capitalize} succeeded"
                else
                  logger.warn "#{type.capitalize} failed! #{cmd} returned #{res.exitstatus}"
                  success = false
                  failed_command = type
                  break
                end
              rescue => e
                logger.error "Error encountered running #{type} command: #{e.message}"
                success = false
                failed_command = type
                break
              end
            end
          end
        end
        return success
      ensure
        # we want to roll back files only if check failed
        if failed_command == :check && success == false
          _rollback updated_targets
        end
      end
    end

    def _rollback updated_targets
      files_to_rollback = updated_targets.reject {|x| x[:backup].nil? }
      files_to_remove = updated_targets.select{|x| x[:backup].nil? }.map{|x| x[:file]}
      logger.warn "Performing rollback of modified files"
      unless files_to_remove.empty?
        logger.debug "Removing #{files_to_remove.join " "}"
        File.unlink(*files_to_remove)
      end
      files_to_rollback.each do |target|
        logger.debug "Moving #{target[:backup]} to #{target[:file]}"
        FileUtils.mv target[:backup], target[:file]
      end
    end

  end
end
