require 'merlin'
require 'logger'
require 'erubis'
require 'fileutils'
require 'open3'
require 'merlin/logstub'
require 'tmpdir'
require 'merlin/monkey_patch/pathname'

#TODO debounce events if configured, so we dont constantly emit configs

module Merlin
  class Emitter
    include Logstub
    attr_accessor :destination, :template_map, :static_map

    def initialize(name, template_map, destination, opts = {})
      @check_cmd, @commit_cmd, @logger = opts[:check_cmd], opts[:commit_cmd], opts[:logger]
      @name = name
      # atomic commit means we will atomically mv the tmp output dir to destination
      # if not set, we will copy each file into the destination before committing
      @atomic = opts[:atomic] ? true : false
      @destination = Pathname.new(destination)
      if @atomic
        if @destination.directory? && !@destination.symlink?
          # ensure destination is either absent, or a symlink and not a directory
          raise "Destination #{destination} must not be a directory when using atomic=true"
        end
      elsif !@destination.directory?
        raise "Destination #{destination} not a directory"
      end
      unless opts[:tmp].nil?
        @custom_tmp = Pathname.new(opts[:tmp])
        raise "Custom tmp #{@custom_tmp} not a directory" unless @custom_tmp.directory?
        raise "Custom tmp #{@custom_tmp} not a writable" unless @custom_tmp.writable?
      end
      raise "You should give me something to template" if template_map.empty?
      @template_map = template_map
      # and test the same for all static files
      if opts[:statics].is_a? Enumerable and ! opts[:statics].is_a? Hash
        static_map = Hash[opts[:statics].map {|f| [f,Pathname.new(f).basename]}]    # make map of input->output
      else
        static_map = opts[:statics] || {}                    # assume empty if missin_map
      end
      @static_map = static_map
      # all outputs must be relative. raise if not
      static_map.each {|i,o| raise "Static file output #{o} must be relative!" unless Pathname.new(o).relative? }
      template_map.each {|i,o| raise "Template output #{o} must be relative!" unless Pathname.new(o).relative? }
    end


    # returns a boolean of update success
    # true if there were changes, and the check and commit succeeded
    # false otherwise (i.e. any check or commit failures, template exceptions, etc)
    def emit data
      target_output = template_map.map do |template,target|
        begin
          logger.info "Expanding template #{template}"
          input = File.read(template)
          erb = Erubis::Eruby.new(input)
          output = erb.result({ :data => data })
          [target,output]
        rescue => e
          logger.error "Error expanding template #{template}: #{e.message}"
          raise e
        end
      end
      target_output = Hash[target_output]

      static_output = static_map.map do |input,target|
        begin
          logger.info "Reading static file #{input}"
          output = File.read(input)
          [target,output]
        rescue => e
          logger.error "Error reading static file #{input}: #{e.message}"
          raise e
        end
      end
      target_output = target_output.merge(Hash[static_output])
      # target_output is a map of relative paths to new contents

      changes_detected = target_output.any? do |target,output|
        _contents_changed(Pathname.new(target).expand_path(destination), output)
      end

      if !changes_detected
        logger.info "No changes detected; skipping check and commit"
        return false
      end

      # write targets and statics to tmp, run check, and possibly rollback
      tmp = Dir.mktmpdir(".merlin-#{@name}-",@custom_tmp)
      logger.debug "Created tmp directory #{tmp}"
      begin
        target_output.each {|target,output| _write_to(target,tmp,output) }
        success = run_command(:check, {
          :dest => tmp,
          :files => target_output.keys.map {|p| File.join(tmp,p)},
        })
        unless success
          # rollback! just nuke the tmp directory :)
          logger.warn "Cleaning up #{tmp} after failed check"
          FileUtils.remove_entry_secure(tmp)
        else
          # perform commit
          if @atomic
            logger.info "Performing atomic deploy of #{tmp} to #{destination}"
            # copy tmp to destination.$(date +%s)
            timestamped_destination = File.join(File.dirname(destination),File.basename(destination) + "." + Time.now.to_i.to_s)
            if File.directory? timestamped_destination
              # TODO maybe just tack on some suffix until it doesnt exist instead of erroring?
              logger.error "Unable to copy #{tmp} to #{timestamped_destination}; already exists"
              raise Errno::EISDIR, timestamped_directory
            end
            logger.debug "Copying #{tmp} to #{timestamped_destination}"
            FileUtils.cp_r(tmp,timestamped_destination)
            logger.debug "Atomically linking #{destination} -> #{timestamped_destination}"
            Pathname.new(destination).atomic_ln_sfn(timestamped_destination)
            #TODO we should probably clean up directories (some # of changes? timewindow?)
          else
            logger.info "Moving outputs from #{tmp} to #{destination}"
            target_output.keys.each do |rel_target|
              _move_to(Pathname.new(tmp).join(rel_target), Pathname.new(destination).join(rel_target))
            end
          end
          success = run_command(:commit, {
            :dest => destination,
            :files => target_output.keys.map {|p| File.join(destination,p)},
          })
        end
        success
      ensure
        if Dir.exists? tmp
          logger.debug "Cleaning up #{tmp}"
          FileUtils.remove_entry_secure(tmp)
        end
      end
    end

    private

    def run_command type, template_vars
      cmd = template_command type, template_vars
      success = true
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
          end
        rescue => e
          logger.error "Error encountered running #{type} command: #{e.message}"
          success = false
        end
      end
      success
    end

    # given a command type, expand any erb in it with exposed values
    # type is one of [:check, :commit]
    def template_command type, template_vars
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
        erb = Erubis::Eruby.new(command)
        erb.result(template_vars)
      rescue => e
        logger.error "Error templating #{type} command! #{e.message}"
        raise e
      end
    end

    def _contents_changed(target, new_output)
      target = Pathname.new(target) unless target.is_a? Pathname
      og_hash = if target.exist? and target.readable?
          Digest::SHA256.file(target).hexdigest
        else
          "none"
        end
      new_hash = Digest::SHA256.hexdigest(new_output)
      logger.debug "#{target} SHA256: #{og_hash}, new contents: #{new_hash}"
      if og_hash == new_hash
        logger.info "No change to #{target}"
        false
      else
        logger.info "#{target} contents changed"
        true
      end
    end

    def _move_to(src, dest)
      dest = Pathname.new(dest) unless dest.is_a? Pathname
      dest = dest.expand_path
      unless dest.dirname.directory?
        logger.debug "Creating path #{dest.dirname} for #{dest}"
        FileUtils.mkdir_p(dest.dirname)
      end
      logger.info "Moving #{src} to #{dest}"
      FileUtils.mv src, dest
    end

    def _write_to(target, dir, output)
      outfile = Pathname.new(dir).join(target)
      unless outfile.dirname.directory?
        logger.debug "Creating path #{outfile.dirname} for #{target}"
        FileUtils.mkdir_p(outfile.dirname)
      end
      logger.info "Writing #{outfile}"
      File.open(outfile,'w'){|f| f.write output}
    end

  end
end
