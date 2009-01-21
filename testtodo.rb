$LOAD_PATH << "/Users/rahul/work/projects/rbcurse/"
require 'rubygems'
require 'ncurses'
require 'logger'
require 'lib/ver/ncurses'
#require 'lib/ver/keyboard'
require 'lib/ver/window'
require 'lib/rbcurse/rwidget'
require 'lib/rbcurse/rcombo'
require 'lib/rbcurse/rtable'
require 'lib/rbcurse/celleditor'
#require 'lib/rbcurse/table/tablecellrenderer'
require 'lib/rbcurse/comboboxcellrenderer'
require 'lib/rbcurse/keylabelprinter'
require 'lib/rbcurse/applicationheader'

class TodoList
  def initialize file
    @file = file
  end
  def load 
    @todomap = YAML::load(File.open(@file));
  end
  def get_statuses
    @todomap['__STATUSES']
  end
  def get_modules
    @todomap['__MODULES'].sort
  end
  def get_categories
    @todomap.keys.delete_if {|k| k.match(/^__/) }
  end
  def get_tasks_for_category categ
    c = @todomap[categ]
    d = []
    c.each_pair {|k,v|
      v.each do |r| 
        row=[]
        row << k
        r.each { |r1| row << r1 }
        d << row
        #$log.debug " ROW = #{row.inspect} "
      end
    }
    return d
  end
  def set_tasks_for_category categ, data
    d = {}
    data.each do |row|
      #key = row.delete_at 0
      key = row.first
      d[key] ||= []
      d[key] << row[1..-1]
    end
    @todomap[categ]=d
    $log.debug " NEW DATA #{categ}: #{data}"
  end
  def dump
    f = "#{@file}"
    File.open(f, "w") { |f| YAML.dump( @todomap, f )}
  end
end
def get_key_labels
  key_labels = [
    ['C-q', 'Exit'], nil,
    ['M-s', 'Save'], ['M-m', 'Move']
  ]
  return key_labels
end
def get_key_labels_table
  key_labels = [
    ['M-n','NewRow'], ['M-d','DelRow'],
    ['C-x','Select'], nil,
    ['M-0', 'Top'], ['M-9', 'End'],
    ['C-p', 'PgUp'], ['C-n', 'PgDn'],
    ['M-Tab','Nxt Fld'], ['Tab','Nxt Col'],
    ['+','Widen'], ['-','Narrow']
  ]
  return key_labels
end
class TodoApp
  def initialize
    @window = VER::Window.root_window
    @form = Form.new @window

    @todo = TodoList.new "todo.yml"
    @todo.load
  end
  def make_popup
    require 'lib/rbcurse/rpopupmenu'
    tablemenu = RubyCurses::PopupMenu.new "Table"
    tablemenu.add(item = RubyCurses::MenuItem.new("Open",'O'))

    tablemenu.insert_separator 1
    tablemenu.add(RubyCurses::MenuItem.new "New",'N')
    tablemenu.add(item = RubyCurses::MenuItem.new("Save",'S'))
    tablemenu.add(item = RubyCurses::MenuItem.new("Test",'T'))
    tablemenu.add(item = RubyCurses::MenuItem.new("Wrap Text",'W'))
    tablemenu.add(item = RubyCurses::MenuItem.new("Exit",'X'))
    item.command() {
      #throw(:menubarclose);
      #throw(:close)
    }
    item=RubyCurses::MenuItem.new "Select"
    item.accelerator = "Ctrl-X"
    tablemenu.add(item)
    item=RubyCurses::MenuItem.new "New Row"
    item.accelerator = "Alt-N"
    tablemenu.add(item)
    item=RubyCurses::MenuItem.new "Delete"
    item.accelerator = "Alt-D"
    tablemenu.add(item)
    tablemenu.show @atable, 0,1
  end
  def run
    todo = @todo
    statuses = todo.get_statuses
    cats = todo.get_categories
    modules = todo.get_modules
    title = "TODO APP"
    @header = ApplicationHeader.new @form, title, {"text2"=>"Some Text", "text_center"=>"Task Entry"}
    status_row = RubyCurses::Label.new @form, {'text' => "", "row" => Ncurses.LINES-4, "col" => 0, "display_length"=>60}
    #@window.printstring 0,(Ncurses.COLS-title.length)/2,title, $datacolor
    r = 1; c = 1;
    categ = ComboBox.new @form do
      name "categ"
      row r
      col 15
      display_length 10
      editable false
      list cats
      set_buffer 'TODO'
      set_label Label.new @form, {'text' => "Category", 'color'=>'cyan','col'=>1, "mnemonic"=>"C"}
      list_config 'height' => 4
      bind(:ENTER){ status_row.text "Select a category and <TAB> out. KEY_UP, KEY_DOWN, M-Down" }
      bind(:LEAVE){ status_row.text "" }
    end
    data = todo.get_tasks_for_category 'TODO'
    @data = data
    $log.debug " data is #{data}"
    colnames = %w[ Module Prior Task Status]

    table_ht = 15
    atable = Table.new @form do
      name   "tasktable" 
      row  r+2
      col  c
      width 78
      height table_ht
      #title "A Table"
      #title_attrib (Ncurses::A_REVERSE | Ncurses::A_BOLD)
      cell_editing_allowed true
      editing_policy :EDITING_AUTO
      set_data data, colnames
    end
    @atable = atable
    categ.bind(:CHANGED) do |fld| $log.debug " COMBO EXIT XXXXXXXX"; 
    data = todo.get_tasks_for_category fld.getvalue; 
    @data = data
    $log.debug " DATA is #{data.inspect} : #{data.length}"
    data = [[nil, 5, "NEW ", "TODO", Time.now]] if data.nil? or data.empty? or data.size == 0
    $log.debug " DATA is #{data.inspect} : #{data.length}"
    atable.table_model.data = data
    end

    tcm = atable.get_table_column_model
    #
    ## key bindings fo atable
    # column widths 
    $log.debug " tcm #{tcm.inspect}"
    $log.debug " tcms #{tcm.columns}"
    tcm.column(0).width 8
    tcm.column(1).width 5
    tcm.column(2).width 50
    tcm.column(3).width 8
    app = self
    atable.configure() do
      #bind_key(330) { atable.remove_column(tcm.column(atable.focussed_col)) rescue ""  }
      bind_key(?+) {
        acolumn = atable.column atable.focussed_col()
        w = acolumn.width + 1
        acolumn.width w
        #atable.table_structure_changed
      }
      bind_key(?-) {
        acolumn = atable.column atable.focussed_col()
        w = acolumn.width - 1
        if w > 3
          acolumn.width w
          #atable.table_structure_changed
        end
      }
      bind_key(?>) {
        colcount = tcm.column_count-1
        #atable.move_column sel_col.value, sel_col.value+1 unless sel_col.value == colcount
        col = atable.focussed_col
        atable.move_column col, col+1 unless col == colcount
      }
      bind_key(?<) {
        col = atable.focussed_col
        atable.move_column col, col-1 unless col == 0
        #atable.move_column sel_col.value, sel_col.value-1 unless sel_col.value == 0
      }
      bind_key(?\M-h, app) {|tab,td| $log.debug " BIND... #{tab.class}, #{td.class}"; app.make_popup }
    end
    #keylabel = RubyCurses::Label.new @form, {'text' => "", "row" => r+table_ht+3, "col" => c, "color" => "yellow", "bgcolor"=>"blue", "display_length"=>60, "height"=>2}
    #eventlabel = RubyCurses::Label.new @form, {'text' => "Events:", "row" => r+table_ht+6, "col" => c, "color" => "white", "bgcolor"=>"blue", "display_length"=>60, "height"=>2}

    # report some events
    #atable.table_model.bind(:TABLE_MODEL_EVENT){|e| #eventlabel.text = "Event: #{e}"}
    #atable.get_table_column_model.bind(:TABLE_COLUMN_MODEL_EVENT){|e| eventlabel.text = "Event: #{e}"}
    atable.bind(:TABLE_TRAVERSAL_EVENT){|e| @header.text_right "Row #{e.newrow+1} of #{atable.row_count}" }


    str_renderer = TableCellRenderer.new ""
    num_renderer = TableCellRenderer.new "", { "justify" => :right }
    bool_renderer = CheckBoxCellRenderer.new "", {"parent" => atable, "display_length"=>5}
    combo_renderer =  RubyCurses::ComboBoxCellRenderer.new nil, {"parent" => atable, "display_length"=> 8}
    combo_editor = RubyCurses::CellEditor.new(RubyCurses::ComboBox.new nil, {"focusable"=>false, "visible"=>false, "list"=>statuses, "display_length"=>8})
    combo_editor1 = RubyCurses::CellEditor.new(RubyCurses::ComboBox.new nil, {"focusable"=>false, "visible"=>false, "list"=>modules, "display_length"=>8})
    atable.set_default_cell_renderer_for_class "String", str_renderer
    atable.set_default_cell_renderer_for_class "Fixnum", num_renderer
    atable.set_default_cell_renderer_for_class "Float", num_renderer
    atable.set_default_cell_renderer_for_class "TrueClass", bool_renderer
    atable.set_default_cell_renderer_for_class "FalseClass", bool_renderer
    atable.get_table_column_model.column(3).cell_editor =  combo_editor
    atable.get_table_column_model.column(0).cell_editor =  combo_editor1
    ce = atable.get_default_cell_editor_for_class "String"
    # increase the maxlen of task
    ce.component.maxlen = 80
    # I want up and down to go up and down rows inside the combo box, i can use M-down for changing.
    combo_editor.component.unbind_key(KEY_UP)
    combo_editor.component.unbind_key(KEY_DOWN)
    combo_editor1.component.unbind_key(KEY_UP)
    combo_editor1.component.unbind_key(KEY_DOWN)
    atable.bind(:TABLE_EDITING_EVENT) do |evt|
      #return if evt.oldvalue != evt.newvalue
      $log.debug " TABLE_EDITING : #{evt} "
      if evt.type == :EDITING_STOPPED
        if evt.col == 3
          if @data[evt.row].size == 4
            @data[evt.row] << Time.now
          else
            @data[evt.row][4] == Time.now
          end
        end
      end
    end
=begin
      combo_editor.component.bind(:CHANGED){
        alert("CHANGED, #{atable.focussed_row}, #{@data[atable.focussed_row].size}")
        if @data.size == 4
          @data[atable.focussed_row] << Time.now
        else
          @data[atable.focussed_row][4] == Time.now
        end
        $log.debug "THSI ROW #{@data[atable.focussed_row]}"
        $log.debug "DATAAAA: #{@data}"
      }
=end
    #combo_editor.component.bind(:LEAVE){ alert "LEAVE"; $log.debug " LEAVE FIRED" }
    buttrow = r+table_ht+8 #Ncurses.LINES-4
    buttrow = Ncurses.LINES-5
    b_save = Button.new @form do
      text "&Save"
      row buttrow
      col c
      command {
        # this does not trigger a data change since we are not updating model. so update
        # on pressing up or down
        #0.upto(100) { |i| data << ["test", rand(100), "abc:#{i}", rand(100)/2.0]}
        #atable.table_data_changed
        todo.set_tasks_for_category categ.getvalue, data
        todo.dump
        alert("Rewritten yaml file")
      }
      bind(:ENTER) { status_row.text "Save changes to todo.yml " }
    end
    b_newrow = Button.new @form do
      text "&New"
      row buttrow
      col c+10
      bind(:ENTER) { status_row.text "New button adds a new row below current " }
    end
    new_cmd = lambda { 
      cc = atable.get_table_column_model.column_count
      frow = atable.focussed_row
      mod = atable.get_value_at(frow,0)
      tmp = [mod, 5, "", "TODO", Time.now]
      tm = atable.table_model
      tm.insert frow+1, tmp
      atable.set_focus_on frow+1
      status_row.text = "Added a row. Please press Save before changing Category."
      alert("Added a row below current one. Use C-k to clear task.")
    }
    b_newrow.command { new_cmd.call }

    # using ampersand to set mnemonic
    b_delrow = Button.new @form do
      text "&Delete"
      row buttrow
      col c+20
      bind(:ENTER) { status_row.text "Deletes focussed row" }
    end
    b_delrow.command { |form| 
      row = atable.focussed_row
      if confirm("Do your really want to delete row #{row+1}?")== :YES
        tm = atable.table_model
        tm.delete_at row
      else
        status_row.text = "Delete cancelled"
      end
    }
    b_change = Button.new @form do
      text "&Lock"
      row buttrow
      col c+30
      command {
        r = atable.focussed_row
        #c = sel_col.value
        #$log.debug " Update gets #{field.getvalue.class}"
        #atable.set_value_at(r, c, field.getvalue)
        toggle = atable.column(atable.focussed_col()).editable 
        if toggle.nil? or toggle==true
          toggle = false 
          text "Un&lock"
        else
          toggle = true
          text "&Lock  "
        end
        #eventlabel.text "Set column  #{atable.focussed_col()} editable to #{toggle}"
        atable.column(atable.focussed_col()).editable toggle
        alert("Set column  #{atable.focussed_col()} editable to #{toggle}")
      }
      bind(:ENTER) { status_row.text "Toggles editable state of current column " }
    end
    b_move = Button.new @form do
      text "&Move"
      row buttrow
      col c+40
      bind(:ENTER) { status_row.text "Move current row to Done" }
    end
    b_move.command { |form| 
      return if categ.getvalue == "DONE"
      row = atable.focussed_row
      d = todo.get_tasks_for_category "DONE"
      r = []
      tcm = atable.get_table_column_model
      tcm.each_with_index do |acol, colix|
        r << atable.get_value_at(row, colix)
      end
      # here i ignore the 5th row tht coud have been added
      r << Time.now
      d << r
      todo.set_tasks_for_category "DONE", d
      tm = atable.table_model
      ret = tm.delete_at row
      alert("Moved row #{row} to Done.")
    }
    @klp = RubyCurses::KeyLabelPrinter.new @form, get_key_labels
    @klp.set_key_labels get_key_labels_table, :table
    atable.bind(:ENTER){ @klp.mode :table ;
      status_row.text = "Please press Save (M-s) before changing Category."
    }
    atable.bind(:LEAVE){@klp.mode :normal; 
    }


    @form.repaint
    @window.wrefresh
    Ncurses::Panel.update_panels
    begin
    while((ch = @window.getchar()) != ?\C-q )
      colcount = tcm.column_count-1
      s = keycode_tos ch
      #status_row.text = "Pressed #{ch} , #{s}"
      @form.handle_key(ch)

      @form.repaint
      @window.wrefresh
    end
    ensure
    @window.destroy if !@window.nil?
    end
  end
end
if $0 == __FILE__
  include RubyCurses
  include RubyCurses::Utils

  begin
    # Initialize curses
    VER::start_ncurses  # this is initializing colors via ColorMap.setup
    $log = Logger.new("view.log")
    $log.level = Logger::DEBUG

    colors = Ncurses.COLORS
    $log.debug "START #{colors} colors  ---------"

    catch(:close) do
      t = TodoApp.new
      t.run
  end
  rescue => ex
  ensure
    VER::stop_ncurses
    p ex if ex
    p(ex.backtrace.join("\n")) if ex
    $log.debug( ex) if ex
    $log.debug(ex.backtrace.join("\n")) if ex
  end
end
