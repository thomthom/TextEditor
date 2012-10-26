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

      @text      = "Hello World\nFoo\nBasecamp"
      @font      = 'Arial'
      @style     = 'Normal'
      @size      = 1.m
      @filled    = true
      @extruded  = true
      @extrusion = 0.m
      @align     = 'Left'

      if instance
        @group = instance
        @origin = instance.transformation.origin
        read_properties( instance )
        instance.model.start_operation( 'Edit 3D Text' )
        open_ui()
      end
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
        :dialog_title => '3D Text Editor',
        :width => 316,
        :height => 280,
        :resizable => false
      }
      w = TT::GUI::ToolWindow.new( props )
      w.theme = TT::GUI::Window::THEME_GRAPHITE

      # Text input
      eInputChange = TT::DeferredEvent.new { |value| input_changed( value ) }
      txtInput = TT::GUI::Textbox.new( @text )
      txtInput.multiline = true
      txtInput.top = 5
      txtInput.left = 5
      txtInput.width = 300
      txtInput.height = 140
      txtInput.add_event_handler( :textchange ) { |control|
        eInputChange.call( control.value )
      }
      w.add_control( txtInput )
      
      # Container for font properties
      container = TT::GUI::Container.new
      container.move( 5, 150 )
      container.width  = 300
      container.height = 75
      w.add_control( container )
      
      # Font List
      lstFont = TT::GUI::Listbox.new( [
        'Arial',
        'Tahoma',
        'Verdana',
        'Wingdings'
      ] )
      lstFont.value = @font
      lstFont.add_event_handler( :change ) { |control, value|
        # (!) Control.value isn't updated - this must change.
        @font = value
        input_changed( nil )
      }
      lstFont.move( 35, 0 )
      lstFont.width = 180
      container.add_control( lstFont )
      @dbFont = lstFont
      
      lblFont = TT::GUI::Label.new( 'Font:', lstFont )
      lblFont.top = 0
      lblFont.right = 270
      container.add_control( lblFont )
      
      # Font Style
      lstStyle = TT::GUI::Listbox.new( [
        'Normal',
        'Bold',
        'Italic',
        'Bold Italic'
      ] )
      lstStyle.value = @style
      lstStyle.add_event_handler( :change ) { |control, value|
        @style = value
        input_changed( nil )
      }
      lstStyle.top = 0
      lstStyle.right = 0
      lstStyle.width = 80
      container.add_control( lstStyle )
      @dbStyle = lstStyle
      
      # Text Alignment
      lstAlign = TT::GUI::Listbox.new( [
        'Left',
        'Center',
        'Right'
      ] )
      lstAlign.value = @align
      lstAlign.add_event_handler( :change ) { |control, value|
        #puts control.value
        #puts value
        @align = value
        input_changed( nil )
      }
      lstAlign.move( 35, 25 )
      lstAlign.width = 80
      container.add_control( lstAlign )
      @dbAlign = lstAlign
      
      lblFont = TT::GUI::Label.new( 'Align:', lstAlign )
      lblFont.top = 25
      lblFont.right = 270
      container.add_control( lblFont )

      # Text size
      eSizeChange = TT::DeferredEvent.new { |value| input_changed( nil ) }
      txtSize = TT::GUI::Textbox.new( @size.to_s )
      txtSize.top = 25
      txtSize.right = 0
      txtSize.width = 80
      txtSize.add_event_handler( :textchange ) { |control|
        eSizeChange.call( control.value )
      }
      container.add_control( txtSize )
      @tHeight = txtSize

      lblSize = TT::GUI::Label.new( 'Height:', txtSize )
      lblSize.top = 25
      lblSize.right = 85
      container.add_control( lblSize )

      # Extrude Height
      eExtrudeChange = TT::DeferredEvent.new { |value| input_changed( nil ) }
      txtExtrude = TT::GUI::Textbox.new( @extrusion.to_s )
      txtExtrude.top = 50
      txtExtrude.right = 0
      txtExtrude.width = 80
      txtExtrude.add_event_handler( :textchange ) { |control|
        eExtrudeChange.call( control.value )
      }
      container.add_control( txtExtrude )
      @tExtrusion = txtExtrude
      
      # Form
      lblForm = TT::GUI::Label.new( 'Form:' )
      lblForm.top = 50
      lblForm.right = 270
      container.add_control( lblForm )
      
      # Extrude
      chkExtrude = TT::GUI::Checkbox.new( 'Extrude:' )
      chkExtrude.top = 50
      chkExtrude.right = 85
      chkExtrude.checked = @extruded
      chkExtrude.add_event_handler( :change ) { |control|
        input_changed( nil )
      }
      container.add_control( chkExtrude )
      @cExtrude = chkExtrude
      
      # Filled
      chkFilled = TT::GUI::Checkbox.new( 'Filled' )
      chkFilled.top = 50
      chkFilled.left = 35
      chkFilled.checked = @filled
      chkFilled.add_event_handler( :change ) { |control|
        input_changed( nil )
      }
      container.add_control( chkFilled )
      @cFilled = chkFilled

      # Close Button
      btnClose = TT::GUI::Button.new( 'Close' ) { |control|
        control.window.close
        model = Sketchup.active_model
        model.commit_operation
        model.select_tool( nil )
      }
      btnClose.size( 75, 25 )
      btnClose.right = 5
      btnClose.bottom = 5
      w.add_control( btnClose )
      
      # Hook up events.
      w.on_ready { |window|
        input_changed( @text )
      }

      w.show_window

      @window = w
    end

    def input_changed( value )
      #puts 'input_changed'

      @text = value if value

      @group.entities.clear!
      
      @font      = @dbFont.value
      @style     = @dbStyle.value
      bold       = @dbStyle.value.include?( 'Bold' )
      italic     = @dbStyle.value.include?( 'Italic' )
      @size      = @tHeight.value.to_l
      @filled    = @cFilled.checked
      @extruded  = @cExtrude.checked
      @extrusion = @tExtrusion.value.to_l
      extrusion  = ( @extruded ) ? @extrusion : 0.0
      tolerance = 0
      z = 0

      align = case @align
        when 'Left':    TextAlignLeft
        when 'Center':  TextAlignCenter
        when 'Right':   TextAlignRight
      end # (?) Map to Hash?

      @group.entities.add_3d_text(
        @text,
        align, @font, bold, italic, @size,
        tolerance, z, @filled, extrusion
      )
      write_properties( @group )
    end
    
    def write_properties( entity )
      entity.set_attribute( 'TT_Editor', 'Text',      @text )
      entity.set_attribute( 'TT_Editor', 'Font',      @font )
      entity.set_attribute( 'TT_Editor', 'Style',     @style )
      entity.set_attribute( 'TT_Editor', 'Size',      @size )
      entity.set_attribute( 'TT_Editor', 'Filled',    @filled )
      entity.set_attribute( 'TT_Editor', 'Extruded',  @extruded )
      entity.set_attribute( 'TT_Editor', 'Extrusion', @extrusion )
      entity.set_attribute( 'TT_Editor', 'Align',     @align )
    end

    def read_properties( entity )
      @text      = entity.get_attribute( 'TT_Editor', 'Text',      'Hello World' )
      @font      = entity.get_attribute( 'TT_Editor', 'Font',      'Arial' )
      @style     = entity.get_attribute( 'TT_Editor', 'Style',     'Normal' )
      @size      = entity.get_attribute( 'TT_Editor', 'Size', 	   1.m ).to_l
      @filled    = entity.get_attribute( 'TT_Editor', 'Filled',    true )
      @extruded  = entity.get_attribute( 'TT_Editor', 'Extruded',  true )
      @extrusion = entity.get_attribute( 'TT_Editor', 'Extrusion', 0.m ).to_l
      @align     = entity.get_attribute( 'TT_Editor', 'Align',     'Left' )
    end

  end # class

end # module

file_loaded( __FILE__ )