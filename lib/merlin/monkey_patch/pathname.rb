require 'pathname'
require 'fileutils'
require 'securerandom'
# monkey patched Pathname

class Pathname
  # creates symlink from self –> old
  def atomic_ln_sfn(old)
    suffix = SecureRandom.hex(5)
    # the expand_paths is necessary to strip the trailing / off directories if provided
    tmplink = Pathname.new(self.expand_path.to_s + "-atomic-tmp-" + suffix)
    if File.directory?(tmplink)
      # bail. there is no ruby ln_sfn, so lets not make links inside this dir
      raise "Unable to create temporary link #{tmplink}! Already exists"
    else
      FileUtils.ln_sf(old,tmplink)
    end
    begin
      puts "Renaming #{tmplink} to #{self.expand_path}"
      tmplink.rename(self.expand_path)
    rescue
      File.unlink(tmplink.to_s)
      raise
    end
  end
end
