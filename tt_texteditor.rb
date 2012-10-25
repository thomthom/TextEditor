module TT_Writer

  unless file_loaded?( __FILE__ )
    # Menus
    m = UI.menu( 'Draw' )
    m.add_item( 'Editable 3d Text' ) { self.writer_tool }

    UI.add_context_menu_handler { |context_menu|
      instance = Sketchup.active_model.selection.find { |e| TT::Instance.is?(e) }
      context_menu.add_item( 'Edit Text' ) {
        Sketchup.active_model.select_tool( TextEditorTool.new( instance ) )
      } if instance
    }
  end

  def self.writer_tool
    Sketchup.active_model.select_tool( TextEditorTool.new )
  end


  class TextEditorTool

    def initialize( instance = nil )
      @origin = nil
      @group = nil
      @ip = Sketchup::InputPoint.new

      @text = "Hello World\nFoo\nBasecamp"
      @bold   = false
      @italic = false
      @size   = 1.m
      @extrude = 0.m
      @align  = 'Left'

      if instance
        @group = instance
        @origin = instance.transformation.origin
        read_properties( instance )
        instance.model.start_operation( 'Edit 3D Text' )
        open_ui()
      end

      #puts @text
      #puts @bold
      #puts @italic
      #puts @size
      #puts @extrude
      #puts @align
    end

    def resume( view )
      view.invalidate
    end

    def deactivate( view )
      view.invalidate
    end

    def onLButtonUp( flags, x, y, view )
      @ip.pick( view, x, y )
      if @origin.nil?
        @origin = @ip.position
        view.model.start_operation( 'Create 3D Text' )
        @group = view.model.active_entities.add_group
        tr = Geom::Transformation.new( @origin )
        @group.transform!( tr )

        open_ui()
      end
      view.invalidate
    end

    def onMouseMove( flags, x, y, view )
      view.invalidate
    end

    def draw( view )
      if @origin
        view.draw_points( [@origin], 10, 4, 'red' )
      end
    end

    private

    def open_ui
      props = {
        :dialog_title => 'Text Editor',
        :width => 216,
        :height => 280,
        :resizable => false
      }
      w = TT::GUI::ToolWindow.new( props )
      w.theme = TT::GUI::Window::THEME_GRAPHITE

      eInputChange = DeferredEvent.new { |value| input_changed( value ) }
      txtInput = TT::GUI::Textbox.new( @text )
      txtInput.multiline = true
      txtInput.top = 5
      txtInput.left = 5
      txtInput.width = 200
      txtInput.height = 100
      txtInput.add_event_handler( :textchange ) { |control|
        eInputChange.call( control.value )
      }
      w.add_control( txtInput )

      eSizeChange = DeferredEvent.new { |value| input_changed( nil ) }
      txtSize = TT::GUI::Textbox.new( @size.to_s )
      txtSize.top = 130
      txtSize.left = 35
      txtSize.width = 50
      txtSize.add_event_handler( :textchange ) { |control|
        eSizeChange.call( control.value )
      }
      w.add_control( txtSize )
      @tHeight = txtSize

      lblSize = TT::GUI::Label.new( 'Size:', txtSize )
      lblSize.top = 130
      lblSize.left = 5
      w.add_control( lblSize )

      eExtrudeChange = DeferredEvent.new { |value| input_changed( nil ) }
      txtExtrude = TT::GUI::Textbox.new( @extrude.to_s )
      txtExtrude.top = 130
      txtExtrude.left = 155
      txtExtrude.width = 50
      txtExtrude.add_event_handler( :textchange ) { |control|
        eExtrudeChange.call( control.value )
      }
      w.add_control( txtExtrude )
      @tExtrude = txtExtrude

      lblExtrude = TT::GUI::Label.new( 'Extrude:', txtExtrude )
      lblExtrude.top = 130
      lblExtrude.left = 110
      w.add_control( lblExtrude )

      chkBold = TT::GUI::Checkbox.new( 'Bold' )
      chkBold.move( 5, 155 )
      chkBold.checked = @bold
      w.add_control( chkBold )
      chkBold.add_event_handler( :change ) { |control|
        #puts 'bold change event'
        input_changed( nil )
      }
      @cBold = chkBold

      chkItalic = TT::GUI::Checkbox.new( 'Italic' )
      chkItalic.move( 50, 155 )
      chkItalic.checked = @italic
      chkItalic.add_event_handler( :change ) { |control|
        #puts 'italic change event'
        input_changed( nil )
      }
      w.add_control( chkItalic )
      @cItalic = chkItalic

      list = TT::GUI::Listbox.new( [
        'Left',
        'Center',
        'Right'
      ] )
      list.add_event_handler( :change ) { |control, value|
        #puts control.value
        #puts value
        @align = value
        input_changed( nil )
      }
      list.move( 5, 185 )
      list.width = 200
      w.add_control( list )
      @dbAlign = list

      btnClose = TT::GUI::Button.new( 'Close' ) { |control|
        #puts 'close'
        control.window.close
        model = Sketchup.active_model
        model.commit_operation
        model.select_tool( nil )
      }
      btnClose.size( 75, 28 )
      btnClose.right = 5
      btnClose.bottom = 5
      w.add_control( btnClose )

      w.show_window

      TT.defer { input_changed( @text ) }

      @window = w
    end

    def input_changed( value )
      #puts 'input_changed'

      @text = value if value

      @group.entities.clear!
      
      @bold   = @cBold.checked
      @italic = @cItalic.checked
      @size   = @tHeight.value.to_l
      @extrude= @tExtrude.value.to_l

      if @align == 'Left'
        align = TextAlignLeft
      elsif @align == 'Center'
        align = TextAlignCenter
      elsif @align == 'Right'
        align = TextAlignRight
      end

      @group.entities.add_3d_text( @text, align, 'Arial', @bold, @italic, @size, 0, 0, true, @extrude )
      write_properties( @group )
    end
    
    def write_properties( entity )
      entity.set_attribute( 'TT_Editor', 'Text',    @text )
      entity.set_attribute( 'TT_Editor', 'Bold',    @bold )
      entity.set_attribute( 'TT_Editor', 'Italic',  @italic )
      entity.set_attribute( 'TT_Editor', 'Size',    @size )
      entity.set_attribute( 'TT_Editor', 'Extrude', @extrude )
      entity.set_attribute( 'TT_Editor', 'Align',   @align )
    end

    def read_properties( entity )
      @text   = entity.get_attribute( 'TT_Editor', 'Text',    'Hello World' )
      @bold   = entity.get_attribute( 'TT_Editor', 'Bold',    false )
      @italic = entity.get_attribute( 'TT_Editor', 'Italic',  false )
      @size   = entity.get_attribute( 'TT_Editor', 'Size', 	  1.m ).to_l
      @extrude= entity.get_attribute( 'TT_Editor', 'Extrude', 0.m ).to_l
      @align  = entity.get_attribute( 'TT_Editor', 'Align',   'Left' )
    end

  end # class

  # (!) Move to TT_Lib
  class DeferredEvent
    
    def initialize( delay = 0.2, &block )
      @proc = block
      @delay = delay
      @last_value = nil
      @timer = nil
    end
    
    def call( value )
      return false if value == @last_value
      UI.stop_timer( @timer ) if @timer
      @timer = UI.start_timer( @delay, false ) {
        UI.stop_timer( @timer ) # Ensure it only runs once.
        @proc.call( value )
      }
      true
    end
    
  end # class DeferredEvent

end # module

file_loaded( __FILE__ )