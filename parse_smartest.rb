#require 'rubygems'
require 'optparse'

require "./lib/DansRubyLibrary"
include DansRubyLibrary

#require 'logger'

# -- parse_church_data.rb <filename.csv>--
#
# Purpose:
#  Parse through smartest test flow file to help for comparison
#  and analysis purposes.
#
#  Outputs CSV to display, capture to file if desired
#

def get_limits(options={})
  options = {
  }.merge(options)

  # all limits
  @test_limits = []

  # go thru file data
  @limits_lines.each_index do |linenum|
    line = @limits_lines[linenum]
    line.gsub!(/\r/,""); line.gsub!(/\n/,"")

    test_limit = {} 
    temp = line.split(',')

    if temp[0] =~ /Suite name/ || temp[0] =~ /Test mode/ || temp[0] == "\"\""
      #DH TBD-- for now only supports 1 limit 'test mode' type
      # e.g. FT (not for various inserts)
    else
      test_limit[:test_suite] = temp[0]
      test_limit[:pins] = temp[1]
      test_limit[:test_name] = temp[2]
      test_limit[:test_number] = temp[3]
      test_limit[:lo_limit] = temp[4]
      test_limit[:lolim_type] = temp[5]
      test_limit[:hilim_type] = temp[6]
      test_limit[:hi_limit] = temp[7]
      test_limit[:units] = temp[8]
      test_limit[:bin_s_num] = temp[9]
      test_limit[:bin_s_name] = temp[10]
      test_limit[:bin_h_num] = temp[11]
      test_limit[:bin_h_name] = temp[12]
      test_limit[:bin_type] = temp[13]
      test_limit[:bin_reprobe] = temp[14]
      test_limit[:bin_overon] = temp[15]
      test_limit[:test_remarks] = temp[16]
      @test_limits << test_limit
    end
  end
end

def print_limits(options={})
  options={
    #ignore_fields: [],              # list of limits fields you want to ignore
                                    # will not print out column at all
                                    # DO NOT ignore 'test_suite' or 'test_name'
    
    ignore_fields: [:bin_s_num, :bin_s_name, :bin_h_num, :bin_h_name, :bin_type,
                    :bin_reprobe, :bin_overon, :test_remarks, :test_number]

  }.merge(options)

  test_limits_sorted = @test_limits.sort_by { |k| [k[:test_suite],k[:test_name]] }

  # CSV data
  #
  print "Test Suite, Pins, Test Name, Lo Limit, LoLim Type, Hi Lim Type, Hi Limit, Units\n"
  test_limits_sorted.each do |test_limit|
    print "#{test_limit[:test_suite]}, "

    print "#{test_limit[:pins]}, " unless options[:ignore_fields].include?(:pins)
    print "#{test_limit[:test_name]}, " unless options[:ignore_fields].include?(:test_name)
    print "#{test_limit[:test_number]}, " unless options[:ignore_fields].include?(:test_number)
    print "#{test_limit[:lo_limit]}, " unless options[:ignore_fields].include?(:lo_limit)
    print "#{test_limit[:lolim_type]}, " unless options[:ignore_fields].include?(:lolim_type)
    print "#{test_limit[:hilim_type]}, " unless options[:ignore_fields].include?(:hilim_type)
    print "#{test_limit[:hi_limit]}, " unless options[:ignore_fields].include?(:hi_limit)
    print "#{test_limit[:units]}, " unless options[:ignore_fields].include?(:units)
    print "#{test_limit[:bin_s_num]}, " unless options[:ignore_fields].include?(:bin_s_num)
    print "#{test_limit[:bin_s_name]}, " unless options[:ignore_fields].include?(:bin_s_name)
    print "#{test_limit[:bin_h_num]}, " unless options[:ignore_fields].include?(:bin_h_num)
    print "#{test_limit[:bin_h_name]}, " unless options[:ignore_fields].include?(:bin_h_name)
    print "#{test_limit[:bin_type]}, " unless options[:ignore_fields].include?(:bin_type)
    print "#{test_limit[:bin_reprobe]}, " unless options[:ignore_fields].include?(:bin_reprobe)
    print "#{test_limit[:bin_overon]}, " unless options[:ignore_fields].include?(:bin_overon)
    print "#{test_limit[:test_remarks]}" unless options[:ignore_fields].include?(:test_remarks)
    print "\n"
  end

end

# output test suite section only
def print_test_suite_section(options={})
  options = {
  }.merge(options)

  in_test_suite_section = false

  # go thru file data
  @testflow_lines.each_index do |linenum|
    line = @testflow_lines[linenum]
    line.gsub!(/\r/,""); line.gsub!(/\n/,"")

    if line =~ /^------/ && in_test_suite_section
      in_test_suite_section = false
    end

    if in_test_suite_section
      print "#{line}\n"
    end

    if line =~ /^test_suites/
      in_test_suite_section = true
    end
  end

end

# output test flow section only
def print_test_flow_section (options={})
  options = {
  }.merge(options)

  in_test_flow_section = false
  # go thru file data
  @testflow_lines.each_index do |linenum|
    line = @testflow_lines[linenum]
    line.gsub!(/\r/,""); line.gsub!(/\n/,"")

    if line =~ /^------/ && in_test_flow_section
      in_test_flow_section = false
    end


    if in_test_flow_section
      
      # close all groups for easier comparison
      if line =~ /, open,/
        line.gsub!(/, open,/,", closed, ")
      end
      print "#{line}\n"
    end

    if line =~ /^test_flow/
      in_test_flow_section = true
    end
  end

end

# save test method to master list
# indicate section, either: :class, :parameters, :limits
def save_test_method(test_method, section)
  # hash key based on name
  name_key = test_method[:name].to_sym
  # init key if new test method
  unless @test_methods.has_key?(name_key)
    @test_methods[name_key] = {}
    (@test_methods[name_key])[:name] = test_method[:name]
  end

  # now add data to the global test method hash
  if section == :class
    (@test_methods[name_key])[:class] = test_method[:class]
  end
  if section == :parameters
    # TM parameters get sorted
    (@test_methods[name_key])[:parameters] = test_method[:parameters].gsub(/\s+/,"").split(/\;/).sort.join("\;")
  end
  if section == :limits
    (@test_methods[name_key])[:limits] = test_method[:limits]
  end
end


def get_test_methods(options={})
  options = {
  }.merge(options)

  @test_methods = {}
  test_method = {}

  # init flags
  # can never have more than 1 true at once!
  in_test_method_class_section = false
  in_test_method_parameter_section = false
  in_test_method_limits_section = false

  # go thru file data
  @testflow_lines.each_index do |linenum|
    line = @testflow_lines[linenum]
    line.gsub!(/\r/,""); line.gsub!(/\n/,"")

    # indicate end of any section
    in_test_method_any_section = (in_test_method_class_section || 
                                  in_test_method_parameter_section ||
                                  in_test_method_limits_section)

    if line =~ /^------/ && in_test_method_any_section
      in_test_method_class_section = false
      in_test_method_parameter_section = false
      in_test_method_limits_section = false
      in_test_method_any_section = false
      test_method = {}
    end

  #DH  if in_test_method_any_section

    if (line =~ /^tm_/ &&  line =~ /:$/)
      # New Test Method found!
      # or end of section reached
      
      # Push previous test suite data to test suites array
      # when new test suite found or end of section
      # use test method name as key for easy lookup
      # of the test method data later
      unless test_method.empty?
        if in_test_method_class_section
          save_test_method(test_method, :class)
        end
        if in_test_method_limits_section
          save_test_method(test_method, :limits)
        end
        if in_test_method_parameter_section
          save_test_method(test_method, :parameters)
        end
      end

      # clear test method object
      test_method = {}

      # grab test method name
      name = line.gsub(/:/,"")
      test_method[:name] = name

    end

    if test_method
      # grab testmethod data, depends on which section we're in

      if in_test_method_class_section
        if line =~ /testmethod_class/
          # grab test method class
          temp = line.split(' ')
          line_data = temp[2]
          line_data.gsub!(/;/,"")
          test_method[:class] = line_data
#          print "name: #{test_method[:name]}, class: #{test_method[:class]}\n"
        end
      end
      if in_test_method_parameter_section && line !~ /^tm_/
        
        if line !~ /^$/ && line !~ /end/ && line !~ /^tm_/
          if test_method.has_key?(:parameters)
            test_method[:parameters] += line
          else
            test_method[:parameters] = line
          end
        end
      end
      if in_test_method_limits_section && line !~ /^tm_/
        if line !~ /^$/ && line !~ /end/ && line !~ /^tm_/
#          print "#{line}\n"
          line_data = line.gsub(/;/,"")
          test_method[:limits] = line_data
#          print "#{line_data}"
#          print "name: #{test_method[:name]}, limits: #{test_method[:limits]}\n"
        end
      end

    end # if test_method

    # flush last test method data at end of section
    if line =~ /^end/
      unless test_method.empty?
        if in_test_method_class_section
          save_test_method(test_method, :class)
        end
        if in_test_method_limits_section
          save_test_method(test_method, :limits)
        end
        if in_test_method_parameter_section
          save_test_method(test_method, :parameters)
        end
      end
      in_test_method_class_section = false
      in_test_method_parameter_section = false
      in_test_method_limits_section = false
      in_test_method_any_section = false
    end

    # indicate which test method section we're in
    # this must go at the end of the file data loop
    if line =~ /^testmethods/
      in_test_method_class_section = true
    end
    if line =~ /^testmethodparameters/
      in_test_method_parameter_section = true
    end
    if line =~ /^testmethodlimits/
      in_test_method_limits_section = true
    end
  end

end

# save test suite to master list
def save_test_suite(test_suite)
  @test_suites << test_suite
end

def get_test_suites(options={})
  options = {
  }.merge(options)

  @ts_data_types = [
    :local_flags,
    :override,
    :override_lev_equ_set,
    :override_lev_spec_set,
    :override_levset,
    :override_seqlbl,
    :override_testf,
    :override_tim_spec_set,
    :override_timset,
    :site_control,
    :site_match
  ]

  # all test suites
  @test_suites = []
  test_suite = {} 

  # flag for whether inside a test suite section
  in_test_suite_section = false

  # go thru file data
  @testflow_lines.each_index do |linenum|
    line = @testflow_lines[linenum]
    line.gsub!(/\r/,""); line.gsub!(/\n/,"")

    # indicate end of test_suite section
    if line =~ /^--------/ && in_test_suite_section
      in_test_suite_section = false
    end

    if in_test_suite_section

      if (line =~ /^[a-zA-z]/ && line =~ /:$/)
        # New Test Suite found!
        #
        
        # Push previous test suite data to test suites array
        # when new test suite found 
        unless test_suite.empty?
          save_test_suite(test_suite)
        end
        
        # clear test suite object
        test_suite = {}

        # grab test suite name
        name = line.gsub(/:/,"")
        test_suite[:name] = name

      end

      if test_suite
        # grab test suite data
        @ts_data_types.each do |datatype|
          to_find = Regexp.new (datatype.to_s + " = ")
          # clean up extra spaces around equals sign
          line.gsub!(/  =/,' =')
          line.gsub!(/=  /,'= ')
          if line =~ to_find
            line.gsub!(/, /,"-")  # sub for any comma delimited data
            line.gsub!(/,/,"-")  # sub for any comma delimited data
            temp = line.split(' ')
            line_data = temp[2] # grab data
            line_data.gsub!(/;/,"")    # remove semicolon
            test_suite[datatype.to_sym] = line_data
          end
        end
      end

      # flush last test suite data at end of section
      if line =~ /^end/ 
        unless test_suite.empty?
          save_test_suite(test_suite)
        end
        in_test_suite_section = false
      end

    end # end of test suite sectino

    # indicate inside test_suite section
    # this must go at the end of the file data loop
    if line =~ /^test_suites/
      in_test_suite_section = linenum
    end
  end

end

# print out test suites into CSV format
def print_test_suites(options={})

  # Heading
  print "TEST_SUITE, "
  print "#{@ts_data_types.join(", ")}\n"

  # CSV data
  @test_suites.each do |test_suite|
    print "#{test_suite[:name]}, "
    @ts_data_types.each do |datatype|
      unless datatype == @ts_data_types.first
        print ", "
      end
      print "#{test_suite[datatype.to_sym]}"
    end
    print "\n"
  end
end

# print out test suites with TM data into CSV format
# will omit actual test method names, e.g. tm_1263
def print_test_suites_full(options={})

  # Heading
  print "TEST_SUITE, "
  @ts_data_types.each do |datatype|
    unless datatype == :override_testf
      print "#{datatype.to_s}, "
    end
  end
  print "TM class, "
  print "TM limits, "
  print "TM parameters "
  print "\n"

  test_suites_sorted = @test_suites.sort_by { |k| k[:name] }

  # CSV data
  test_suites_sorted.each do |test_suite|
    print "#{test_suite[:name]}, "
    @ts_data_types.each do |datatype|
      unless datatype == :override_testf
        print "#{test_suite[datatype.to_sym]}, "
      end
    end
    # get associated test method data
    if @test_methods.has_key?(test_suite[:override_testf].to_sym)
      test_method = @test_methods[test_suite[:override_testf].to_sym]
      print "#{test_method[:class]}, "
      print "#{test_method[:limits]}, "
      print "#{test_method[:parameters]}"
    else
      print "ERROR: could not find test method data for '#{test_suite[:override_testf]}'!!"
    end
    print "\n"
  end
end

def print_test_methods(options={})
  # Heading
  print "TEST_METHOD, "
  print "class, "
  print "limits, "
  print "parameters "
  print "\n"

  # CSV data
  @test_methods.each do |name, test_method|
    print "#{test_method[:name]}, "
    print "#{test_method[:class]}, "
    print "#{test_method[:limits]}, "
    print "#{test_method[:parameters]}"
    print "\n"
  end
end

# reads input data from file,
# puts into @testflow_lines
def get_file_data(options={})
  options={ file_type: :testflow 
          }.merge(options)
  fp = FileParser.new
  fp.open(filename: @filename)
  if options[:file_type] == :testflow
    @testflow_lines = fp.readlines
  elsif options[:file_type] == :limits
    @limits_lines = fp.readlines
  else
    fail "Invalid type '#{options[:type]}' passed to 'get_file_data'!"
  end
  fp.close()
end

# main basically
begin

  # interpret command line options
  @command_options = {
    testflow:   false,
    testsuites: true,
  }
  option_parser = OptionParser.new do |opts|
    opts.banner = "Usage: parse_smartest.rb <INPUT FILE> [options]"
    opts.separator ''
    opts.on('-h', '--help', 'Display help' ) { puts opts; exit }
    opts.separator ("--------------------")
    opts.separator (" TEST FLOW options:  ")
    opts.on('-c', '--testsuite_csv', 'Output sorted test suite CSV from a test flow file (Default operation)') { @command_options[:testsuites] = true }
    opts.on('-s', '--testsuite_section', 'Output test suite section from a test flow file') { @command_options[:testsuite_section] = true }
    opts.on('-f', '--testflow_section', 'Output test_flow section from a test flow file') { @command_options[:testflow_section] = true }
    opts.separator ("--------------------")
    opts.separator (" TEST LIMIT options:  ")
    opts.on('-l', '--limits', 'Output sorted limits from a limits file') { @command_options[:limits] = true }
  end

  option_parser.parse!

  # test flow option overrides test suites output option
  if @command_options[:testflow_section] || @command_options[:testsuite_section]
    @command_options[:testsuites] = false
  end
  
  # ERROR CHECKING of arguments
  if ARGV.length != 1
#    raise "ERROR: Invalid number of arguments"
    puts option_parser
    exit
  end
  @filename = ARGV[0]
#  puts "Filename: #{@filename}"

  if @command_options[:limits]
    @command_options[:testflow_section] = false
    @command_options[:testsuite_section] = false
    @command_options[:testsuites] = false
    # limits CSV input file
    if File.extname(@filename) != ".csv"
      raise "ERROR: #{@filename} not a SmarTest CSV file!"
    end
  else
    # assume TF input file
    if File.extname(@filename) != ".tf"
      raise "ERROR: #{@filename} not a SmarTest TF file!"
    end
  end

  # get data from file, into array
  if @command_options[:limits]
    get_file_data(file_type: :limits)
  else
    # test suites or tes flow
    get_file_data
  end

  if @command_options[:testsuites]
    # Process test method data first
    get_test_methods
#    print_test_methods

    # Then process test suite data
    get_test_suites
#    print_test_suites  # for script debug-- does not print out everything
    print_test_suites_full

  elsif @command_options[:testflow_section]
    # process test flow data
    print_test_flow_section if @command_options[:testflow_section] 

  elsif @command_options[:testsuite_section]
    # process test suite data
    print_test_suite_section if @command_options[:testsuite_section] 

  elsif @command_options[:limits]
    get_limits
    print_limits
  end



end
