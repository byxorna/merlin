require 'spec_helper'
require 'merlin/util'

describe Merlin::Util do
  let(:input_relboth) {{
    "filename.erb" => "filename.txt",
    "filename2.erb" => "filename2.txt",
  }}
  let(:input_absin) {{
    "/abs/filename.erb" => "filename.txt",
    "/abs/filename2.erb" => "filename2.txt",
  }}
  let(:input_absout) {{
    "filename.erb" => "/abs/filename.txt",
    "filename2.erb" => "/abs/filename2.txt",
  }}
  let(:input_absboth) {{
    "/abs/filename.erb" => "/abs/filename.txt",
    "/abs/filename2.erb" => "/abs/filename2.txt",
  }}
  let(:input_absary) { ['/abs/filename.txt','/abs/filename2.txt'] }
  let(:input_relary) { ['filename.txt','filename2.txt'] }

  before(:each) { Dir.chdir '/' }
  after(:each) { Dir.chdir '/' }

  context "self.make_absolute_path_hash(input_output,outdir)" do
    it "accepts an array of filenames" do
      res = Merlin::Util.make_absolute_path_hash(input_absary,'/outdir')
      expect(res).to eq({
        '/abs/filename.txt' => '/abs/filename.txt',
        '/abs/filename2.txt' => '/abs/filename2.txt',
      })
      res = Merlin::Util.make_absolute_path_hash(input_relary,'/outdir')
      expect(res).to eq({
        '/filename.txt' => '/outdir/filename.txt',
        '/filename2.txt' => '/outdir/filename2.txt',
      })
    end
    it "makes input keys absolute to pwd" do
      Dir.chdir '/usr'  # we can assume /usr isnt a symlink on linux and osx
      res = Merlin::Util.make_absolute_path_hash(input_relboth,'/outdir')
      expect(res).to eq({
        '/usr/filename.erb' => '/outdir/filename.txt',
        '/usr/filename2.erb' => '/outdir/filename2.txt',
      })
      Dir.chdir '/'
      res = Merlin::Util.make_absolute_path_hash(input_relboth,'/outdir')
      expect(res).to eq({
        '/filename.erb' => '/outdir/filename.txt',
        '/filename2.erb' => '/outdir/filename2.txt',
      })
      res = Merlin::Util.make_absolute_path_hash(input_absin,'/outdir')
      expect(res).to eq({
        '/abs/filename.erb' => '/outdir/filename.txt',
        '/abs/filename2.erb' => '/outdir/filename2.txt',
      })
    end
    it "makes output keys absolute to outdir" do
      res = Merlin::Util.make_absolute_path_hash(input_absout,'/outdir')
      expect(res).to eq({
        '/filename.erb' => '/abs/filename.txt',
        '/filename2.erb' => '/abs/filename2.txt',
      })
      res = Merlin::Util.make_absolute_path_hash(input_relboth,'/outdir')
      expect(res).to eq({
        '/filename.erb' => '/outdir/filename.txt',
        '/filename2.erb' => '/outdir/filename2.txt',
      })
    end
    it "doesnt change absolute paths" do
      res = Merlin::Util.make_absolute_path_hash(input_absboth,'/outdir')
      expect(res).to eq({
        '/abs/filename.erb' => '/abs/filename.txt',
        '/abs/filename2.erb' => '/abs/filename2.txt',
      })
      Dir.chdir '/usr'
      res = Merlin::Util.make_absolute_path_hash(input_absboth,'/outdir')
      expect(res).to eq({
        '/abs/filename.erb' => '/abs/filename.txt',
        '/abs/filename2.erb' => '/abs/filename2.txt',
      })
    end
  end
end

