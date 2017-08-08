#NOTE: Must use at least version 1.9.2 of ruby
#      otherwise String.end_with? won't work!

module DansRubyLibrary

#TODO: Add capability to recursively delete directories in output directory

class DirParser

  def initialize()
    @input_path = ""
    @output_path = ""
    @always_skip_dir = Array.new
    @always_copy_file = Array.new
    @regexpr_list = Hash.new
  end
  
  # add regular expression to list to process
  def add_regexp(from, to)
    @regexpr_list[from] = to
  end
  

  def input_path(value)
    @input_path = value + (value.end_with?("/")? "" : "/")
    if !Dir.exists?(@input_path)
      abort "ERROR: path '#{@input_path}' does not exist!\n"
    end
  end

  def output_path(value)
    @output_path = value + (value.end_with?("/")? "" : "/")
    if !Dir.exists?(@output_path)
      Dir.mkdir(@output_path)
     end
  end

  # adds a directory to a list of directories to skip
  def always_skip_dir(options={}) 
    options={ :skip_dir => "",
            }.merge(options)

    options[:skip_dir] = options[:skip_dir] + ((options[:skip_dir]).end_with?("/")? "" : "/")
    if !(options[:skip_dir].eql?(""))
      @always_skip_dir.push(options[:skip_dir])
    end
  end

  # adds a filename to a list of files to always copy directly
  #  mainly to be used for binary files which are hard to parse
  #  string added here actually can be file extension as 'end_with?' is later used
  def always_copy_file(options={}) 
    options={ :copy_file => "",
            }.merge(options)

    if !(options[:copy_file].eql?(""))
      @always_copy_file.push(options[:copy_file])
    end
  end
  
  def sub_file(options={})
    options={ :inputfilename => "",
              :outputfilename => "",
              :reg_exp_list => @regexpr_list,  # regular exp hash
            }.merge(options)

    if options[:inputfilename].eql?('')
      abort "ERROR: no input filename given to filter_file method!\n"
    end
    if options[:outputfilename].eql?('')
      abort "ERROR: no output filename given to filter_file method!\n"
    end

    if options[:reg_exp_list].empty?
      abort "ERROR: no regular expressions set!\n"
    end
    
    fp = FileParser.new                      # create file parser

    if (check_copy_file(:filename => options[:inputfilename]))
      # file matches copy list-- do not filter but copy instead!

      # Really don't want to use a system command but have no other choice
      print "#{options[:inputfilename]}: file copied!\n"
      `cp #{options[:inputfilename]} #{options[:outputfilename]}`
      return
    end

    print "#{options[:inputfilename]}: file sub'd\n"
    fp.open(:filename => options[:inputfilename])     # open input file
    
    fp.open(:input => false,                 # open output file
            :filename => options[:outputfilename])

    fp.sub_lines(options.merge(:print_to_file => true))

    
    fp.close()                # close input file
    fp.close(:input => false) # close output file
    
    
  end

  def filter_file(options={})
    options={ :inputfilename => "",
              :outputfilename => "",
              :line_filter_regexp => '',       # line filter regular expression
              :file_filter_regexp => '',       # file filter regular expression  
              :file_filter_regexp_lineno => 1, # line no containing file filter regexp
            }.merge(options)

    if options[:inputfilename].eql?('')
      abort "ERROR: no input filename given to filter_file method!\n"
    end
    if options[:outputfilename].eql?('')
      abort "ERROR: no output filename given to filter_file method!\n"
    end

    fp = FileParser.new                      # create file parser

    if (check_copy_file(:filename => options[:inputfilename]))
      # file matches copy list-- do not filter but copy instead!

      # Really don't want to use a system command but have no other choice
      print "#{options[:inputfilename]}: file copied!\n"
      `cp #{options[:inputfilename]} #{options[:outputfilename]}`
      return
    end

    print "#{options[:inputfilename]}: file filtered!\n"

    fp.open(:filename => options[:inputfilename])     # open input file

    if fp.check_file_filter(:filename => options[:inputfilename],
                            :regexp => options[:file_filter_regexp],
                            :line_no => options[:file_filter_regexp_lineno])
      # if file contains file filter regexp then do not output, return
      print "#{options[:inputfilename]}: skipped}\n"
      return
    end

    fp.open(:input => false,                 # open output file
            :filename => options[:outputfilename])

    fp.filter_lines(:regexp => options[:line_filter_regexp],   # filter lines, write output file
                    :print_to_file => true)

    fp.close()                # close input file
    fp.close(:input => false) # close output file


  end

  # delete entire directory-- even if non-empty!  use carefully!
  def delete_dir(options={})
    options={ :path => "",                    # path for which to delete all files
            }.merge(options)

      `\\rm -Rf #{options[:path]}`

  end

  # delete all files in path (hopefully an output directory!)
  # does not delete subdirectories!
  def empty_dir(options={})
    options={ :path => "",                    # path for which to delete all files
              :recurse => true,               # works recursively by default
            }.merge(options)

    if (options[:path]).eql?("")
      abort "ERROR: empty path passed to empty_dir method!\n"
    end

    options[:path] = options[:path] + ((options[:path]).end_with?("/")? "" : "/")

    if !Dir.exists?(options[:path])
      abort "ERROR: path '#{options[:path]} does not exist!\n"
    end
    Dir.foreach(options[:path]) do |dir_entry|
      if !dir_entry.eql?('.') && !dir_entry.eql?('..')   # skip current and parent dirs
        full_entry = options[:path] + dir_entry 
        if !File.directory?(full_entry)
          File.delete(full_entry)
        else
          if options[:recurse] then empty_dir(:path => full_entry) end
        end
      end
    end

  end

  # check if entire directory needs to be filtered, returns true or false
  def check_dir_filter(options={})
    options={ :path => "",
              :dir_filter_filename  => "",     # Filename to be used as key to determine whether to filter directory
            }.merge(options)

    if !Dir.exists?(options[:path])
      abort "ERROR: path '#{options[:path]} does not exist!\n"
    end

    Dir.foreach(options[:path]) do |dir_entry|
      if dir_entry.eql?(options[:dir_filter_filename])
        return true
      end
    end
    return false

  end

  def check_copy_file(options={})
    options={ :filename => "",
            }.merge(options)
    if options[:filename].eql?("")
      abort "ERROR: invalid filename passed to 'check_copy_file'\n"
    end
    @always_copy_file.each do |copy_file|
      if (options[:filename]).end_with?(copy_file)
        return true
      end
    end
    false
  end

  def check_skip_dir(options={})
    options={ :path => "",
            }.merge(options)

    if options[:path].eql?("")
      abort "ERROR: invalid path passed to 'check_skip_dir'\n"
    end
    @always_skip_dir.each do |skip_dir|
      if (options[:path]).end_with?(skip_dir)
        return true
      end
    end
    false
  end
  
  # subsitute text within all files in a directory
  def sub_dir(options={})
    options = {
              :input_path => @input_path,      # input path
              :output_path => @output_path,    # output path
              :reg_exp_list => @regexpr_list,  # regular exp hash
              :delete_output => true,          # delete files in output dir by default prior to running
              :recurse_dir => true,            # recurse through directory structure
              :delete_output_dirs => false,    # whether to delete by brute force, using sys command
    }.merge(options)
    
    if options[:input_path].eql?("")
      abort "ERROR: invalid input_path'\n"
    end
    if options[:output_path].eql?("")
      abort "ERROR: invalid output_path'\n"
    end
    if options[:reg_exp_list].empty?
      abort "ERROR: no regular expressions set!\n"
    end
    
    options[:input_path] = options[:input_path] + ((options[:input_path]).end_with?("/")? "" : "/")
    options[:output_path] = options[:output_path] + ((options[:output_path]).end_with?("/")? "" : "/")

    if !Dir.exists?(options[:input_path])
      abort "ERROR: path '#{options[:input_path]} does not exist!\n"
    end
    
    # delete all files in output directory
    if options[:delete_output_dirs]
      if (Dir.exists?(options[:output_path]))
        delete_dir(:path => options[:output_path])
      end
      # no longer need to empty directories
      options[:delete_output] = false
    end

    if options[:delete_output]
      if (Dir.exists?(options[:output_path]))
        empty_dir(:path => options[:output_path])
        delete_dir(:path => options[:output_path])
      end
    end
    
    # Check if directory needs to be skipped
    if check_skip_dir(:path => options[:input_path])
      print "#{options[:input_path]}: directory skipped.\n"
      return  # do not sub directory
    end

    # delete all files in output directory

    if !Dir.exists?(options[:output_path])
      Dir.mkdir(options[:output_path])
    end
    
    # substitute files
    Dir.foreach(options[:input_path]) do |dir_entry|
      if !dir_entry.eql?('.') && !dir_entry.eql?('..')   # skip current and parent dirs

        full_input_entry = options[:input_path] + dir_entry 
        full_output_entry = options[:output_path] + dir_entry 

        if !File.directory?(full_input_entry)
           sub_file(options.merge(:inputfilename => full_input_entry,
                                    :outputfilename => full_output_entry))
        else
           # DANGER: Using recursion here-- assumes you will eventually runout of files/directories!
           if options[:recurse_dir]
             sub_dir(options.merge(:input_path => full_input_entry, :output_path => full_output_entry))
           end
        end  


      end
    end

  end

  # filter all files in a directory
  def filter_dir(options={})
    options={ 
              :input_path => @input_path,      # input path
              :output_path => @output_path,    # output path
              :line_filter_regexp => '',       # line filter regular expression
              :file_filter_regexp => '',       # file filter regular expression  
              :file_filter_regexp_lineno => 1, # line no containing file filter regexp
              :delete_output => true,          # delete files in output dir by default prior to running
              :recurse_dir => true,            # recurse through directory structure
              :dir_filter_filename => '',      # file name used to indicate a directory should be filtere out
              :delete_output_dirs => false,    # whether to delete by brute force, using sys command
             }.merge(options)

    if options[:input_path].eql?("")
      abort "ERROR: invalid input_path passed to 'filter_dir'\n"
    end
    if options[:output_path].eql?("")
      abort "ERROR: invalid output_path passed to 'filter_dir'\n"
    end

    options[:input_path] = options[:input_path] + ((options[:input_path]).end_with?("/")? "" : "/")
    options[:output_path] = options[:output_path] + ((options[:output_path]).end_with?("/")? "" : "/")

    if !Dir.exists?(options[:input_path])
      abort "ERROR: path '#{options[:input_path]} does not exist!\n"
    end

    # Check if entire directory needs to be filtered or skipped
    if (check_dir_filter(:path => options[:input_path],
                        :dir_filter_filename => options[:dir_filter_filename]) || 
        check_skip_dir(:path => options[:input_path]))
      print "#{options[:input_path]}: directory skipped.\n"
      return  # do not filter directory
    end

    # delete all files in output directory
    if options[:delete_output_dirs]
      if (Dir.exists?(options[:output_path]))
        delete_dir(:path => options[:output_path])
      end
      # no longer need to empty directories
      options[:delete_output] = false
    end

    if options[:delete_output]
      if (Dir.exists?(options[:output_path]))
        empty_dir(:path => options[:output_path])
        delete_dir(:path => options[:output_path])
      end
    end


    if !Dir.exists?(options[:output_path])
      Dir.mkdir(options[:output_path])
    end

    Dir.foreach(options[:input_path]) do |dir_entry|
      if !dir_entry.eql?('.') && !dir_entry.eql?('..')   # skip current and parent dirs

        full_input_entry = options[:input_path] + dir_entry 
        full_output_entry = options[:output_path] + dir_entry 

        if !File.directory?(full_input_entry)
           filter_file(options.merge(:inputfilename => full_input_entry,
                                    :outputfilename => full_output_entry))
        else
           # DANGER: Using recursion here-- assumes you will eventually runout of files/directories!
           if options[:recurse_dir]
             filter_dir(options.merge(:input_path => full_input_entry, :output_path => full_output_entry))
           end
        end  


      end
    end

  end

end #DirParser class

class FileParser

  # Create the object
  def initialize()
  end

  # open either input file for reading or output file for writing
  def open(options={})
    options = { :input => true,
                :filename => '',
              }.merge(options)
    if options[:filename].eql?('')
      abort "ERROR: no filename given to open method!\n"
    end
    if options[:input]
      @infilename = options[:filename]
      @infile = File.new(@infilename, 'r')   # read only file
    else
      @outfilename = options[:filename]
      @outfile = File.new(@outfilename, 'w')   # write only file
    end
  end

  # close either input or output file
  def close(options={})
    options = { :input => true,
              }.merge(options)
    if options[:input]
      @infile.close
    else
      @outfile.close
    end

  end

  # print a line to either stdout or output file
  def print_line(line, to_outfile)
    if to_outfile
      @outfile.syswrite("#{line}")
    else
      print "#{line}"
    end
  end

  # iterator to provide each line of input file
  def per_input_line()
    @infile.each_line("\n") do |row| 
      yield row
    end
  end
  
  def sub_lines(options={})
    options = {
              :reg_exp_list => @regexpr_list,  # regular exp hash
              :print_to_file => false,  # where to print result
              }.merge(options)
    
    if options[:reg_exp_list].empty?
      abort "ERROR: no regular expressions set!\n"
    end
    
    line_no = 0
    per_input_line do |line|
      begin
        line_no = line_no + 1
        tmp_line = "#{line}"
        options[:reg_exp_list].each do |from, to|
          
          if tmp_line.match("#{from.to_s}")
            print "SUB FOUND IN: #{options[:inputfilename]}:#{tmp_line.rstrip}\n"
          end
            tmp_line = tmp_line.gsub("#{from}", "#{to}")
        end
        print_line(tmp_line, options[:print_to_file])
      rescue
        print "Error scanning through file : #{options[:inputfilename]} at line no #{line_no} \n"
        print "  Likely an invalid character, please check\n"
        raise
      end
    end
    
    
    
  end

  def readlines(options={})
    # careful as could use up too much memory!
    # assumes you've already opened the file with 'open' above
    # can also use 'per_input_line' if you need

    @infile.readlines
  end
  alias_method :read_lines, :readlines

  # filter out lines from input file to either stdout or output file
  def filter_lines(options={}) 
    options = { :regexp => '',            # regexp to use for filtering out
                :print_to_file => false,  # where to print result
              }.merge(options)

    line_no = 0
    per_input_line do |line|
      begin
        line_no = line_no + 1
        if (!line.match(options[:regexp]))
          print_line(line, options[:print_to_file])
        end
      rescue
        print "Error scanning through file : #{options[:inputfilename]} at line no #{line_no} \n"
        print "  Likely an invalid character, please check\n"
        raise
      end
    end

  end

  # check to see if file should be filtered out
  # assumes file already opened!!
  # assumes a line # in file contains regexp to check to filter out
  def check_file_filter(options={})
    # returns true if matches file filter regexp on a particular line number
    options = { :regexp => '',            # regexp to use for filtering file
                :line_no => 1,            # line no containing regexp
              }.merge(options)


    if (options[:line_no] < 1)
      abort "ERROR: invalid line_no passed to 'check_file_filter'!\n"
    end

    if @infile.size > 0
      regexp_line = @infile.readlines[options[:line_no] - 1]
      @infile.rewind   # reset file pointer back to 0

      begin
        regexp_line.match(options[:regexp])   # return value
      rescue
        print "Error scanning through file : #{options[:inputfilename]} at line no #{line_no} \n"
        print "  Likely an invalid characer, please check\n"
        raise
      end
    end

  end

end # FileParser class

def print_ruby_version
  patchlevel = " patchlevel #{RUBY_PATCHLEVEL}" if defined? RUBY_PATCHLEVEL
  version = "ruby #{RUBY_VERSION} (#{RUBY_RELEASE_DATE}#{patchlevel}) [#{RUBY_PLATFORM}]"
  puts version
end

end
