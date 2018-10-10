#-------------------------------------------------------------------------------
#
# Thomas Thomassen
# thomas[at]thomthom[dot]net
#
#-------------------------------------------------------------------------------

require 'sketchup.rb'
begin
  require 'TT_Lib2/core.rb'
rescue LoadError => e
  module TT
    if @lib2_update.nil?
      url = 'http://www.thomthom.net/software/sketchup/tt_lib2/errors/not-installed'
      options = {
        :dialog_title => 'TT_Lib² Not Installed',
        :scrollable => false, :resizable => false, :left => 200, :top => 200
      }
      w = UI::WebDialog.new( options )
      w.set_size( 500, 300 )
      w.set_url( "#{url}?plugin=#{File.basename( __FILE__ )}" )
      w.show
      @lib2_update = w
    end
  end
end


#-------------------------------------------------------------------------------

if defined?( TT::Lib ) && TT::Lib.compatible?( '2.11.0', '3D Text Editor' )

module TT::Plugins::Editor3dText


  ### MENU & TOOLBARS ### ------------------------------------------------------

  unless file_loaded?( __FILE__ )
    # Menus
    m = UI.menu( 'Draw' )
    m.add_item( 'Editable 3d Text' ) { self.writer_tool }

    # Context menu
    UI.add_context_menu_handler { |context_menu|
      instance = Sketchup.active_model.selection.find { |entity|
        next unless TT::Instance.is?( entity )
        definition = TT::Instance.definition( entity )
        definition.attribute_dictionary( PLUGIN_ID, false )
      }
      context_menu.add_item( 'Edit Text' ) {
        self.warn_if_incompatible()
        Sketchup.active_model.select_tool( TextEditorTool.new( instance ) )
      } if instance
    }
  end


  ### MAIN SCRIPT ### ----------------------------------------------------------

  # @since 1.0.0
  def self.writer_tool
    self.warn_if_incompatible()
    Sketchup.active_model.select_tool( TextEditorTool.new )
  end


  # @since 1.0.0
  def self.warn_if_incompatible
    @warned ||= false
    if !@warned && TT::System::PLATFORM_IS_OSX
      @warned = true
      # (i) Users report it to be working. Turning out the messagebox.
      puts 'Crash Warning! This plugin might crash SketchUp when run under OSX.'
      #UI.messagebox( 'Crash Warning! This plugin might crash SketchUp when run under OSX.' )
    end
  end


  # @since 1.0.0
  class TextEditorTool

    ALIGN_LEFT   = 'Left'.freeze
    ALIGN_CENTER = 'Center'.freeze
    ALIGN_RIGHT  = 'Right'.freeze

    CURRENT_VERSION = 2

    # @since 1.0.0
    def initialize( instance = nil )
      @origin = nil
      @instance = nil
      @ip = Sketchup::InputPoint.new

      # Default values.
      @text      = "Enter text"
      @font      = read_pref('Font', 'Arial')
      @style     = read_pref('Style', 'Normal')
      @size      = read_pref('Size', 1.m).to_l
      @filled    = read_pref('Filled', true)
      @extruded  = read_pref('Extruded', true)
      @extrusion = read_pref('Extrusion', 0.m).to_l
      @align     = read_pref('Align', ALIGN_LEFT)
      @version   = CURRENT_VERSION

      # Load values from provided instance.
      if instance
        @instance = instance

        definition = TT::Instance.definition( @instance )
        read_properties( definition )

        @origin = instance.transformation.origin

        instance.model.start_operation( 'Edit 3D Text' )
        upgrade_text if @version < 2
        open_ui()
      end
    end

    # @param [Sketchup::View] view
    #
    # @since 1.0.0
    def resume( view )
      view.invalidate
    end

    # @param [Sketchup::View] view
    #
    # @since 1.0.0
    def deactivate( view )
      @window.close if @window && @window.visible?

      if @origin
        view.model.commit_operation
        write_pref('Font', @font)
        write_pref('Style', @style)
        write_pref('Size', @size.to_f)
        write_pref('Filled', @filled)
        write_pref('Extruded', @extruded)
        write_pref('Extrusion', @extrusion.to_f)
        write_pref('Align', @align)
      else
        view.model.abort_operation
      end

      view.invalidate
    end

    def onCancel( reason, view )
      puts "Cancel: #{reason}"
      @origin = nil
      view.model.select_tool( nil )
    end

    # @param [Integer] flags
    # @param [Integer] x
    # @param [Integer] y
    # @param [Sketchup::View] view
    #
    # @since 1.0.0
    def onLButtonUp( flags, x, y, view )
      if @origin.nil? && @mouse_origin
        @origin = @mouse_origin
      end
      view.invalidate
    end

    # @param [Sketchup::PickHelper] pick_helper
    # @param [Sketchup::Face] face
    # @param [Sketchup::Entity] exclude_parent Group, Image or ComponentInstance
    #
    # @return [Geom::Transformation, Nil]
    # @since 1.0.0
    def get_best_face( pick_helper, exclude_parent = nil )
      pick_helper.count.times { |index|
        path = pick_helper.path_at( index )
        next if exclude_parent && path.include?( exclude_parent )
        leaf = path.last
        return leaf if leaf.is_a?( Sketchup::Face )
      }
      nil
    end

    # @param [Sketchup::PickHelper] pick_helper
    # @param [Sketchup::Face] face
    #
    # @return [Geom::Transformation, Nil]
    # @since 1.0.0
    def get_face_transformation( pick_helper, face )
      pick_helper.count.times { |index|
        leaf = pick_helper.leaf_at( index )
        next unless leaf == face
        return pick_helper.transformation_at( index )
      }
      nil
    end

    # @param [Array<Sketchup::Entity>] entities
    #
    # @return [Geom::Transformation, Nil]
    # @since 1.0.0
    def get_ray_transformation( entities )
      tr = Geom::Transformation.new
      for entity in entities
        next unless entity.respond_to?( :transformation )
        tr = tr * entity.transformation
      end
      tr
    end

    # @param [Integer] flags
    # @param [Integer] x
    # @param [Integer] y
    # @param [Sketchup::View] view
    #
    # @since 1.0.0
    def onMouseMove( flags, x, y, view )
      model = view.model

      # Pick a point in the model where the text can be inserted under the
      # cursor. Trying to find an entity to glue to.
      ph = view.pick_helper
      ph.do_pick( x, y )
      face = get_best_face( ph, @instance )
      face_transformation = get_face_transformation( ph, face )

      ray = view.pickray( x, y )
      result = model.raytest( ray )
      if result
        point = result[0]
      else
        plane = [ORIGIN, Z_AXIS]
        point = Geom.intersect_line_plane( ray, plane )
        # (!) Error catch.
      end

      @mouse_origin = point

      # Create the text definition when needed.
      if @instance.nil?
        #@temp_origin = point
        model.start_operation( 'Create 3D Text' )
        name = model.definitions.unique_name( 'Editable 3D Text' )
        definition = model.definitions.add( name )
        definition.behavior.is2d = true
        definition.behavior.snapto = SnapTo_Arbitrary
        write_properties( definition )
        tr = Geom::Transformation.new( point )
        @instance = model.active_entities.add_instance( definition, tr )
        update_3d_text( definition.entities )
        open_ui()
      end

      # Position the text in the model. Glue to instance if possible.
      if @origin.nil?
        position = @mouse_origin || ORIGIN
        # Align instance to face.
        if face
          view.tooltip = 'Align to face'
          normal = face.normal.transform( face_transformation )
          tr = Geom::Transformation.new( position, normal )
          @instance.glued_to = nil if @instance.glued_to
          @instance.transformation = tr
          if face.parent.entities == model.active_entities
            @instance.glued_to = face
          end
        # No face found - simply position.
        else
          view.tooltip = 'No align'
          tr = Geom::Transformation.new( position )
          @instance.transformation = tr
        end
      end

      view.invalidate
    end

    # @param [Sketchup::View] view
    #
    # @since 1.0.0
    def draw( view )
      if @origin
        view.draw_points( [@origin], 10, 4, 'red' )
      end

      if @instance
        view.draw_points( [@instance.transformation.origin], 10, 4, 'green' )
      end
    end

    private

    # @return [TT::GUI::Window]
    # @since 1.0.0
    def open_ui
      props = {
        :dialog_title => '3D Text Editor',
        :width => 325,
        :height => 300,
        :resizable => false
      }
      w = TT::GUI::ToolWindow.new( props )
      w.theme = TT::GUI::Window::THEME_GRAPHITE

      # Deferred event - preventing call to a method to be called too often and
      # unless the value actually changes.
      eChange = TT::DeferredEvent.new { |value|
        input_changed( value )
      }
      eChange.suppress_event_if_value_not_changed = false

      # Text input
      txtInput = TT::GUI::Textbox.new( @text )
      txtInput.name = :txt_input
      txtInput.multiline = true
      txtInput.top = 5
      txtInput.left = 5
      txtInput.width = 300
      txtInput.height = 140
      txtInput.add_event_handler( :textchange ) { |control|
        # (!) .dup is required to avoid BugSplat under SketchUp.
        #
        # That alone is not enough. It appear that TT::DeferredEvent will cause
        # a bugsplat. All though I don't understand why. Under Windows it works
        # fine. This project has had a lot of OSX issues... :/
        if TT::System::PLATFORM_IS_OSX
          input_changed( control.value.dup ) if control.value != @text
        else
          eChange.call( control.value.dup )
        end
      }
      w.add_control( txtInput )

      # Container for font properties
      container = TT::GUI::Container.new
      container.move( 5, 150 )
      container.width  = 300
      container.height = 75
      w.add_control( container )

      # Font List
      lstFont = TT::GUI::Listbox.new()
      lstFont.name = :lst_font
      lstFont.add_event_handler( :change ) { |control, value|
        # (!) Control.value isn't updated - this must change.
        @font = value
        input_changed( nil )
      }
      lstFont.move( 35, 0 )
      lstFont.width = 180
      container.add_control( lstFont )

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
      lstStyle.name = :lst_style
      lstStyle.value = @style
      lstStyle.add_event_handler( :change ) { |control, value|
        @style = value
        input_changed( nil )
      }
      lstStyle.top = 0
      lstStyle.right = 0
      lstStyle.width = 80
      container.add_control( lstStyle )

      # Text Alignment
      lstAlign = TT::GUI::Listbox.new( [
        ALIGN_LEFT,
        ALIGN_CENTER,
        ALIGN_RIGHT
      ] )
      lstAlign.name = :lst_align
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

      lblFont = TT::GUI::Label.new( 'Align:', lstAlign )
      lblFont.top = 25
      lblFont.right = 270
      container.add_control( lblFont )

      # Text size
      txtSize = TT::GUI::Textbox.new( @size.to_s )
      txtSize.name = :txt_size
      txtSize.top = 25
      txtSize.right = 0
      txtSize.width = 80
      txtSize.add_event_handler( :textchange ) { |control|
        if TT::System::PLATFORM_IS_OSX
          input_changed( nil )
        else
          eChange.call( nil )
        end
      }
      container.add_control( txtSize )

      lblSize = TT::GUI::Label.new( 'Height:', txtSize )
      lblSize.top = 25
      lblSize.right = 85
      container.add_control( lblSize )

      # Extrude Height
      txtExtrude = TT::GUI::Textbox.new( @extrusion.to_s )
      txtExtrude.name = :txt_extrusion
      txtExtrude.enabled = @filled # Disable when text is not filled.
      txtExtrude.top = 50
      txtExtrude.right = 0
      txtExtrude.width = 80
      txtExtrude.add_event_handler( :textchange ) { |control|
        if TT::System::PLATFORM_IS_OSX
          input_changed( nil )
        else
          eChange.call( nil )
        end
      }
      container.add_control( txtExtrude )

      # Form
      lblForm = TT::GUI::Label.new( 'Form:' )
      lblForm.top = 50
      lblForm.right = 270
      container.add_control( lblForm )

      # Extrude
      chkExtrude = TT::GUI::Checkbox.new( 'Extrude:' )
      chkExtrude.name = :chk_extrude
      chkExtrude.enabled = @filled # Disable when text is not filled.
      chkExtrude.top = 50
      chkExtrude.right = 85
      chkExtrude.checked = @extruded
      chkExtrude.add_event_handler( :change ) { |control|
        input_changed( nil )
      }
      container.add_control( chkExtrude )

      # Filled
      chkFilled = TT::GUI::Checkbox.new( 'Filled' )
      chkFilled.name = :chk_filled
      chkFilled.top = 50
      chkFilled.left = 35
      chkFilled.checked = @filled
      chkFilled.add_event_handler( :change ) { |control|
        input_changed( nil )
        txtExtrude.enabled = control.checked
        chkExtrude.enabled = control.checked
      }
      container.add_control( chkFilled )

      # Close Button
      btnClose = TT::GUI::Button.new( 'Close' ) { |control|
        control.window.close
      }
      btnClose.size( 75, 25 )
      btnClose.right = 5
      btnClose.bottom = 5
      w.add_control( btnClose )

      # Hook up events.
      w.on_ready { |window|
        # Populate Font list.
        font_names = list_system_fonts
        font = font_names.include?(@font) ? @font : default_font(font_names)
        font_list = w[:lst_font]
        font_list.add_item(font_names)
        font_list.value = font
        # Update 3D Text.
        input_changed( @text )
      }

      w.set_on_close {
        on_window_close()
      }

      w.show_window

      @window = w
    end

    # @since 1.0.0
    def on_window_close
      model = Sketchup.active_model
      model.select_tool( nil )
    end

    def to_length_or_default(string, default)
      string.to_l
    rescue ArgumentError
      default.to_l
    end

    # @since 1.0.0
    def input_changed( value )
      #puts "\ninput_changed"

      @text = value if value

      w = @window
      #@font      = w[:lst_font].value
      #@style     = w[:lst_style].value
      @size      = to_length_or_default(w[:txt_size].value, @size)
      @filled    = w[:chk_filled].checked
      @extruded  = w[:chk_extrude].checked
      @extrusion = to_length_or_default(w[:txt_extrusion].value, @extrusion)

      definition = TT::Instance.definition( @instance )
      definition.entities.clear!

      # OSX seem more agressive in trying to erase an empty component. If you
      # use entities.add_3d_text with an empty string into an empty component it
      # will erase that component definition.
      # (I thought that happened only on operation commit...)
      update_3d_text( definition.entities ) unless @text.strip.empty?
      write_properties( definition )
    end

    # @since 1.0.0
    def update_3d_text( entities )
      #puts 'update_3d_text'

      bold       = @style.include?( 'Bold' )
      italic     = @style.include?( 'Italic' )

      align = case @align
        when ALIGN_LEFT   then TextAlignLeft
        when ALIGN_CENTER then TextAlignCenter
        when ALIGN_RIGHT  then TextAlignRight
      end # (?) Map to Hash?

      extrusion  = ( @extruded ) ? @extrusion : 0.0
      tolerance = 0
      z = 0

      entities.add_3d_text(
        @text,
        align, @font, bold, italic, @size,
        tolerance, z, @filled, extrusion
      )

      # Align instance to Text Alignment.
      origin = @origin || @mouse_origin
      position = get_align_point( @instance, @align, origin )

      @align_pt = position

      align_text(@instance, @align)
    end

    def align_text( instance, alignment )
      definition = TT::Instance.definition( instance )

      left_pt  = definition.bounds.corner(0) # (left front bottom)
      right_pt = definition.bounds.corner(1) # (right front bottom)
      mid_pt   = Geom::linear_combination( 0.5, left_pt, 0.5, right_pt )

      if alignment == ALIGN_LEFT
        vector = Geom::Vector3d.new(0, 0, 0)
      elsif alignment == ALIGN_CENTER
        vector = mid_pt.vector_to( left_pt )
      elsif alignment == ALIGN_RIGHT
        vector = right_pt.vector_to( left_pt )
      end

      return unless vector.valid?

      tr = Geom::Transformation.new(vector)

      entities = definition.entities
      entities.transform_entities(tr, entities.to_a)
    end

    def upgrade_text
      # puts 'Upgrading 3D Editable Text object...'
      # Adjust the transformation from earlier versions so they don't shift
      # when being edited by newer versions.
      origin = @instance.transformation.origin
      position = get_align_point( @instance, @align, origin )
      vector = origin.vector_to( position )
      if vector.valid?
        @instance.transform!(vector.reverse)
      end
      @origin = @instance.transformation.origin
      @version = CURRENT_VERSION
    end

    # @since 1.0.0
    def get_align_point( instance, alignment, origin )
      definition = TT::Instance.definition( instance )

      left_pt  = definition.bounds.corner(0) # (left front bottom)
      right_pt = definition.bounds.corner(1) # (right front bottom)
      mid_pt   = Geom::linear_combination( 0.5, left_pt, 0.5, right_pt )

      if alignment == ALIGN_LEFT
        vector = Geom::Vector3d.new(0, 0, 0)
      elsif alignment == ALIGN_CENTER
        vector = mid_pt.vector_to( left_pt )
      elsif alignment == ALIGN_RIGHT
        vector = right_pt.vector_to( left_pt )
      end

      position = origin.clone
      if vector.valid?
        vector.transform!( instance.transformation )
        position.offset!( vector )
      end

      position
    end

    # @since 1.0.0
    def write_properties( entity )
      entity.set_attribute( PLUGIN_ID, 'Text',      @text )
      entity.set_attribute( PLUGIN_ID, 'Font',      @font )
      entity.set_attribute( PLUGIN_ID, 'Style',     @style )
      entity.set_attribute( PLUGIN_ID, 'Size',      @size )
      entity.set_attribute( PLUGIN_ID, 'Filled',    @filled )
      entity.set_attribute( PLUGIN_ID, 'Extruded',  @extruded )
      entity.set_attribute( PLUGIN_ID, 'Extrusion', @extrusion )
      entity.set_attribute( PLUGIN_ID, 'Align',     @align )
      entity.set_attribute( PLUGIN_ID, 'Version',   @version )
    end

    # @since 1.0.0
    def read_properties( entity )
      @text      = entity.get_attribute( PLUGIN_ID, 'Text',      @text )
      @font      = entity.get_attribute( PLUGIN_ID, 'Font',      @font )
      @style     = entity.get_attribute( PLUGIN_ID, 'Style',     @style )
      @size      = entity.get_attribute( PLUGIN_ID, 'Size',      @size ).to_l
      @filled    = entity.get_attribute( PLUGIN_ID, 'Filled',    @filled )
      @extruded  = entity.get_attribute( PLUGIN_ID, 'Extruded',  @extruded )
      @extrusion = entity.get_attribute( PLUGIN_ID, 'Extrusion', @extrusion ).to_l
      @align     = entity.get_attribute( PLUGIN_ID, 'Align',     @align )
      @version   = entity.get_attribute( PLUGIN_ID, 'Version',   1 )
    end

    # @since 1.0.0
    def default_font( availible_fonts )
      # TODO(thomthom): Remember last used font.
      fallbacks = [
        'Arial',
        'Helvetica',
        'Tahoma',
        'Trebuchet MS',
        'Verdana'
      ]
      matches = availible_fonts & fallbacks
      # (!) Validate
      matches.first
    end

    # @since 1.0.0
    def list_system_fonts
      # Try to get list of system fonts. Cache the list for later use.
      @font_names ||= TT::System.font_names
      @font_names
    end

    def read_pref(key, default)
      Sketchup.read_default(PLUGIN_ID, key, default) || default
    rescue SyntaxError => error
      # NOTE(thomthom): It appear that this isn't getting caught. Instead SU
      # print out the error and return nil. (Hence the `|| default` part above.)
      # In case junk data is read in, recover and emit some indication that
      # something went amiss.
      puts error
      return default
    end

    def write_pref(key, value)
      Sketchup.write_default(PLUGIN_ID, key, value)
    end

  end # class


  ### DEBUG ### ----------------------------------------------------------------

  # @note Debug method to reload the plugin.
  #
  # @example
  #   TT::Plugins::Editor3dText.reload
  #
  # @param [Boolean] tt_lib
  #
  # @return [Integer]
  # @since 1.0.0
  def self.reload( tt_lib = false )
    original_verbose = $VERBOSE
    $VERBOSE = nil
    TT::Lib.reload if tt_lib
    # Core file (this)
    load __FILE__
    # Supporting files
    #x = Dir.glob( File.join(PATH, '*.{rb,rbs}') ).each { |file|
    #  load file
    #}
    #x.length
  ensure
    $VERBOSE = original_verbose
  end

end # module

end # if TT_Lib

#-------------------------------------------------------------------------------

file_loaded( __FILE__ )

#-------------------------------------------------------------------------------
