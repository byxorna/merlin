require 'merlin'
require 'logger'
require 'erubis'
require 'fileutils'
require 'open3'
require 'merlin/logstub'
require 'merlin/util'
require 'pathname'

#TODO make template inflation and checking files for content changes multithreaded
#TODO debounce events if configured, so we dont constantly emit configs
#TODO support changes to the static assets as well

module Merlin
  class Emitter
    include Logstub
    attr_accessor :templates, :destination, :static_files
    def check_cmd
      _template_command :check
    end
    def commit_cmd
      _template_command :commit
    end

    def initialize(templates,destination, opts = {})
      @check_cmd, @commit_cmd, @logger = opts[:check_cmd], opts[:commit_cmd], opts[:logger]
      # ensure directory is a thing
      dest = File.stat(destination)
      raise "#{destination} not a directory" unless dest.directory?
      raise "#{destination} not a writable" unless dest.writable?
      @destination = File.absolute_path destination
      #ensure templates are readable
      unreadable = templates.keys.reject{|t| File.readable? t}
      raise "Unable to read templates: #{unreadable.inspect}" unless unreadable.empty?

      # if static_files given, make sure they are all readable
      # and resolve them to be absolute
      @static_files = {}
      if ! opts[:static_files].nil? && ! opts[:static_files].empty?
        static_files = Util.make_absolute_path_hash(opts[:static_files], @destination)
        puts static_files.inspect
        unreadable_static = static_files.keys.reject{|f| File.readable?(f) && !File.directory?(f)}
        raise "Unable to read static files: #{unreadable_static.join ','}" unless unreadable_static.empty?
        @static_files = static_files
      end
      # resolve templates and outputs to absolute if not already
      @templates = Util.make_absolute_path_hash(templates,@destination)
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
        #target = File.join(destination,target)
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
          #TODO fix writing targets to point into a temp directory?
          tmptarget = File.join(File.dirname(target),".#{File.basename(target)}-#{Time.now.to_i}")
          logger.info "Writing #{tmptarget}"
          File.open(tmptarget,'w') { |f| f.write(output) }
          logger.debug "Moving #{tmptarget} to #{target}"
          FileUtils.mv tmptarget, target
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

    # given a command type, expand any erb in it with exposed values
    # type is one of [:check, :commit]
    def _template_command type
      # ignore missing commands
      command = case type
      when :check
        @check_cmd
      when :commit
        @commit_cmd
      else
        raise "I dont know what a #{type} command is!"
      end
      return nil if command.nil?
      begin
        destination = @destination
        static_outputs = @static_files
        dynamic_outputs = @templates.values
        outputs = static_outputs + dynamic_outputs
        erb = Erubis::Eruby.new(command)
        erb.result(binding)
      rescue => e
        logger.error "Error templating #{type} command! #{e.message}"
        raise e
      end
    end

  end
end
