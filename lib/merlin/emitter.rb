require 'merlin'
require 'logger'
require 'erubis'
require 'fileutils'
require 'open3'

#TODO make template inflation and checking files for content changes multithreaded
#TODO debounce events if configured, so we dont constantly emit configs
#TODO support changes to the static assets as well

module Merlin
  class Emitter
    attr_accessor :templates, :destination, :logger, :check_cmd, :commit_cmd
    def initialize(name,templates,destination,check_cmd = nil, commit_cmd = nil)
      @name, @check_cmd, @commit_cmd = name, check_cmd, commit_cmd
      # ensure directory is a thing
      dest = File.stat(destination)
      raise "#{destination} not a directory" unless dest.directory?
      raise "#{destination} not a writable" unless dest.writable?
      @destination = destination
      #ensure templates are readable
      unreadable = templates.keys.reject{|t| File.readable? t}
      raise "Unable to read templates: #{unreadable.inspect}" unless unreadable.empty?
      @templates = templates
      @logger = Logger.new STDOUT, "emitter::#{@name}"
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
            logger.debug "Moving #{target} to #{target}.bak"
            FileUtils.mv target, "#{target}.bak"
          end
          logger.info "Writing #{target}"
          File.open(target,'w') { |f| f.write(output) }
          target
        end
      end.compact

      return _check_and_commit updated_targets
    end

    private
    def _check_and_commit updated_targets
      success = true
      unless updated_targets.empty?
        {:check => check_cmd, :commit => commit_cmd}.each do |type,cmd|
          if cmd.nil?
            logger.info "No #{type} command specified, skipping check"
          else
            logger.info "Running #{type} command: #{cmd}"
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
              success = false
              logger.warn "#{type.capitalize} failed! #{cmd} returned #{res.exitstatus}"
              if type == :check
                logger.warn "Rolling back modified files: #{updated_targets.join " "}"
                updated_targets.each do |target|
                  FileUtils.mv "#{target}.bak", target
                end
              end
              break
            end
          end
        end
      end
      return success
    end

  end
end
