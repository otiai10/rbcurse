#require 'rubygems'
#require 'ncurses'
#require 'logger'
require 'rbcurse/rwidget'
module RubyCurses

  ## 
  #  2010-09-27 11:06 : i have modified this quite a bit, to calculate some stuff
  #  once in the init, to reduce work in repaint
  # This is a basic list cell renderer that will render the to_s value of anything.
  # Using alignment one can use for numbers too.
  # However, for booleans it will print true and false. If editing, you may want checkboxes
  class ListCellRenderer
    include RubyCurses::ConfigSetup
    include RubyCurses::Utils
    dsl_accessor :justify     # :right, :left, :center  # added 2008-12-22 19:02 
    dsl_accessor :display_length     #  please give this to ensure the we only print this much
    dsl_accessor :height    # if you want a multiline label.
    dsl_accessor :text    # text of label
    dsl_accessor :color, :bgcolor
    dsl_accessor :row, :col
    dsl_accessor :parent    #usuall the table to get colors and other default info

    def initialize text="", config={}, &block
      @text = text
      @editable = false
      @focusable = false
      config_setup config # @config.each_pair { |k,v| variable_set(k,v) }
      instance_eval &block if block_given?
      init_vars
    end
    def init_vars
      @justify ||= (@parent.justify || :left)
      @format = @justify.to_sym == :right ? "%*s" : "%-*s"  
      @display_length ||= 10
      # create color pairs once for this 2010-09-26 20:53 
      @color_pair = get_color $datacolor
      @pairs = Hash.new(@color_pair)
      @attrs = Hash.new(Ncurses::A_NORMAL)
      color_pair = get_color $selectedcolor, @parent.selected_color, @parent.selected_bgcolor
      @pairs[:normal] = @color_pair
      @pairs[:selected] = color_pair
      @pairs[:focussed] = @pairs[:normal]
      @attrs[:selected] = $row_selected_attr
      @attrs[:focussed] = $row_focussed_attr

    end
    def getvalue
      @text
    end
    ##
    # sets @color_pair and @attr
    def select_colors focussed, selected
      @color_pair = @pairs[:normal]
      @attr = $row_attr
      # give precedence to a selected row
      if selected
        @color_pair = @pairs[:selected]
        @attr       = @attrs[:selected]
      elsif focussed
        @color_pair = @pairs[:focussed]
        @attr       = @attrs[:focussed]
      end
    end

    ##
    #  paint a list box cell
    #
    #  @param [Buffer] window or buffer object used for printing
    #  @param [Fixnum] row
    #  @param [Fixnum] column
    #  @param [Fixnum] actual index into data, some lists may have actual data elsewhere and
    #                  display data separate. e.g. rfe_renderer (directory listing)
    #  @param [String] text to print in cell
    #  @param [Boolean, cell focussed, not focussed
    #  @param [Boolean] cell selected or not
    def repaint graphic, r=@row,c=@col, row_index=-1,value=@text, focussed=false, selected=false

      select_colors focussed, selected 
      # if listboxes width is reduced, display_len remains the same
      @display_length = @parent.width - 2 - @parent.left_margin

      value=value.to_s
      if !@display_length.nil?
        if value.length > @display_length
          value = value[0..@display_length-1]
        end
        # added 2010-09-27 11:05 TO UNCOMMENT AND TEST IT OUT
        if @justify == :center
          value = value.center(@display_length)
        end
      end
      len = @display_length || value.length
      $log.debug " CELLREND len #{len} "
      graphic.printstring r, c, @format % [len, value], @color_pair, @attr
    end # repaint
  end # class

end # module
