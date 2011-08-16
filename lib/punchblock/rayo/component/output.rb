module Punchblock
  class Rayo
    module Component
      class Output < CommandNode
        register :output, :output

        ##
        # Creates an Rayo Output command
        #
        # @param [Hash] options
        # @option options [String, Optional] :text to speak back
        # @option options [String, Optional] :voice with which to render TTS
        # @option options [Audio, Optional] :audio to play
        # @option options [String, Optional] :ssml document to render TTS
        #
        # @return [Rayo::Command::Output] an Rayo "output" command
        #
        # @example
        #   output :text => 'Hello brown cow.'
        #
        #   returns:
        #     <output xmlns="urn:xmpp:tropo:output:1">Hello brown cow.</output>
        #
        def self.new(options = {})
          super().tap do |new_node|
            case options
            when Hash
              new_node.voice = options.delete(:voice) if options[:voice]
              new_node.ssml = options.delete(:ssml) if options[:ssml]
              new_node << options.delete(:text) if options[:text]
              if audio = options.delete(:audio)
                audio = Audio.new(audio) unless audio.is_a?(Audio)
                new_node << audio
              end
              options.each_pair { |k,v| new_node.send :"#{k}=", v }
            when Nokogiri::XML::Element
              new_node.inherit options
            end
          end
        end

        ##
        # @return [String] the TTS voice to use
        #
        def interrupt_on
          read_attr :'interrupt-on', :to_sym
        end

        ##
        # @param [String] voice to use when rendering TTS
        #
        def interrupt_on=(other)
          write_attr :'interrupt-on', other
        end

        ##
        # @return [String] the TTS voice to use
        #
        def start_offset
          read_attr :'start-offset', :to_i
        end

        ##
        # @param [String] voice to use when rendering TTS
        #
        def start_offset=(other)
          write_attr :'start-offset', other
        end

        ##
        # @return [String] the TTS voice to use
        #
        def start_paused
          read_attr(:'start-paused') == 'true'
        end

        ##
        # @param [String] voice to use when rendering TTS
        #
        def start_paused=(other)
          write_attr :'start-paused', other.to_s
        end

        ##
        # @return [String] the TTS voice to use
        #
        def repeat_interval
          read_attr :'repeat-interval', :to_i
        end

        ##
        # @param [String] voice to use when rendering TTS
        #
        def repeat_interval=(other)
          write_attr :'repeat-interval', other
        end

        ##
        # @return [String] the TTS voice to use
        #
        def repeat_times
          read_attr :'repeat-times', :to_i
        end

        ##
        # @param [String] voice to use when rendering TTS
        #
        def repeat_times=(other)
          write_attr :'repeat-times', other
        end

        ##
        # @return [String] the TTS voice to use
        #
        def max_time
          read_attr(:'max-time').to_i
        end

        ##
        # @param [String] voice to use when rendering TTS
        #
        def max_time=(other)
          write_attr :'max-time', other
        end

        ##
        # @return [String] the TTS voice to use
        #
        def voice
          read_attr :voice
        end

        ##
        # @param [String] voice to use when rendering TTS
        #
        def voice=(other)
          write_attr :voice, other
        end

        ##
        # @return [String] the SSML document to render TTS
        #
        def ssml
          content.strip
        end

        ##
        # @param [String] ssml the SSML document to render TTS
        #
        def ssml=(ssml)
          if ssml.instance_of?(String)
            self << RayoNode.new('').parse(ssml) do |config|
              config.noblanks.strict
            end
          end
        end

        def inspect_attributes # :nodoc:
          [:voice, :audio, :ssml] + super
        end

        state_machine :state do
          event :paused do
            transition :executing => :paused
          end

          event :resumed do
            transition :paused => :executing
          end
        end

        # Pauses a running Output
        #
        # @return [Rayo::Command::Output::Pause] an Rayo pause message for the current Output
        #
        # @example
        #    output_obj.pause_action.to_xml
        #
        #    returns:
        #      <pause xmlns="urn:xmpp:tropo:output:1"/>
        def pause_action
          Pause.new :component_id => component_id, :call_id => call_id
        end

        ##
        # Sends an Rayo pause message for the current Output
        #
        def pause!
          raise InvalidActionError, "Cannot pause a Output that is not executing." unless executing?
          result = connection.write call_id, pause_action, component_id
          paused! if result
        end

        ##
        # Create an Rayo resume message for the current Output
        #
        # @return [Rayo::Command::Output::Resume] an Rayo resume message
        #
        # @example
        #    output_obj.resume_action.to_xml
        #
        #    returns:
        #      <resume xmlns="urn:xmpp:tropo:output:1"/>
        def resume_action
          Resume.new :component_id => component_id, :call_id => call_id
        end

        ##
        # Sends an Rayo resume message for the current Output
        #
        def resume!
          raise InvalidActionError, "Cannot resume a Output that is not paused." unless paused?
          result = connection.write call_id, resume_action, component_id
          resumed! if result
        end

        class Pause < Action # :nodoc:
          register :pause, :output
        end

        class Resume < Action # :nodoc:
          register :resume, :output
        end

        ##
        # Creates an Rayo stop message for the current Output
        #
        # @return [Rayo::Command::Output::Stop] an Rayo stop message
        #
        # @example
        #    output_obj.stop_action.to_xml
        #
        #    returns:
        #      <stop xmlns="urn:xmpp:tropo:output:1"/>
        def stop_action
          Stop.new :component_id => component_id, :call_id => call_id
        end

        ##
        # Sends an Rayo stop message for the current Output
        #
        def stop!
          raise InvalidActionError, "Cannot stop a Output that is not executing." unless executing?
          connection.write call_id, stop_action, component_id
        end

        ##
        # Creates an Rayo seek message for the current Output
        #
        # @return [Rayo::Command::Output::Seek] a Rayo seek message
        #
        # @example
        #    output_obj.seek_action.to_xml
        #
        #    returns:
        #      <seek xmlns="urn:xmpp:rayo:output:1"/>
        def seek_action(options = {})
          Seek.new({ :component_id => component_id, :call_id => call_id }.merge(options)).tap do |s|
            s.original_component = self
          end
        end

        ##
        # Sends a Rayo seek message for the current Output
        #
        def seek!(options = {})
          raise InvalidActionError, "Cannot seek an Output that is already seeking." if seeking?
          connection.write call_id, seek_action(options), component_id
        end

        state_machine :seek_status, :initial => :not_seeking do
          event :seeking do
            transition :not_seeking => :seeking
          end

          event :stopped_seeking do
            transition :seeking => :not_seeking
          end
        end

        class Seek < Action # :nodoc:
          register :seek, :output

          def self.new(options = {})
            super.tap do |new_node|
              new_node.direction  = options[:direction]
              new_node.amount     = options[:amount]
            end
          end

          def direction=(other)
            write_attr :direction, other
          end

          def amount=(other)
            write_attr :amount, other
          end

          def request!
            source.seeking!
            super
          end

          def execute!
            source.stopped_seeking!
            super
          end
        end

        ##
        # Creates an Rayo speed up message for the current Output
        #
        # @return [Rayo::Command::Output::SpeedUp] a Rayo speed up message
        #
        # @example
        #    output_obj.speed_up_action.to_xml
        #
        #    returns:
        #      <speed-up xmlns="urn:xmpp:rayo:output:1"/>
        def speed_up_action
          SpeedUp.new(:component_id => component_id, :call_id => call_id).tap do |s|
            s.original_component = self
          end
        end

        ##
        # Sends a Rayo speed up message for the current Output
        #
        def speed_up!
          raise InvalidActionError, "Cannot speed up an Output that is already speeding." unless not_speeding?
          connection.write call_id, speed_up_action, component_id
        end

        ##
        # Creates an Rayo slow down message for the current Output
        #
        # @return [Rayo::Command::Output::SlowDown] a Rayo slow down message
        #
        # @example
        #    output_obj.slow_down_action.to_xml
        #
        #    returns:
        #      <speed-down xmlns="urn:xmpp:rayo:output:1"/>
        def slow_down_action
          SlowDown.new(:component_id => component_id, :call_id => call_id).tap do |s|
            s.original_component = self
          end
        end

        ##
        # Sends a Rayo slow down message for the current Output
        #
        def slow_down!
          raise InvalidActionError, "Cannot slow down an Output that is already speeding." unless not_speeding?
          connection.write call_id, slow_down_action, component_id
        end

        state_machine :speed_status, :initial => :not_speeding do
          event :speeding_up do
            transition :not_speeding => :speeding_up
          end

          event :slowing_down do
            transition :not_speeding => :slowing_down
          end

          event :stopped_speeding do
            transition [:speeding_up, :slowing_down] => :not_speeding
          end
        end

        class SpeedUp < Action # :nodoc:
          register :'speed-up', :output

          def request!
            source.speeding_up!
            super
          end

          def execute!
            source.stopped_speeding!
            super
          end
        end

        class SlowDown < Action # :nodoc:
          register :'speed-down', :output

          def request!
            source.slowing_down!
            super
          end

          def execute!
            source.stopped_speeding!
            super
          end
        end

        ##
        # Creates an Rayo volume up message for the current Output
        #
        # @return [Rayo::Command::Output::VolumeUp] a Rayo volume up message
        #
        # @example
        #    output_obj.volume_up_action.to_xml
        #
        #    returns:
        #      <volume-up xmlns="urn:xmpp:rayo:output:1"/>
        def volume_up_action
          VolumeUp.new(:component_id => component_id, :call_id => call_id).tap do |s|
            s.original_component = self
          end
        end

        ##
        # Sends a Rayo volume up message for the current Output
        #
        def volume_up!
          raise InvalidActionError, "Cannot volume up an Output that is already voluming." unless not_voluming?
          connection.write call_id, volume_up_action, component_id
        end

        ##
        # Creates an Rayo volume down message for the current Output
        #
        # @return [Rayo::Command::Output::VolumeDown] a Rayo volume down message
        #
        # @example
        #    output_obj.volume_down_action.to_xml
        #
        #    returns:
        #      <volume-down xmlns="urn:xmpp:rayo:output:1"/>
        def volume_down_action
          VolumeDown.new(:component_id => component_id, :call_id => call_id).tap do |s|
            s.original_component = self
          end
        end

        ##
        # Sends a Rayo volume down message for the current Output
        #
        def volume_down!
          raise InvalidActionError, "Cannot volume down an Output that is already voluming." unless not_voluming?
          connection.write call_id, volume_down_action, component_id
        end

        state_machine :volume_status, :initial => :not_voluming do
          event :voluming_up do
            transition :not_voluming => :voluming_up
          end

          event :voluming_down do
            transition :not_voluming => :voluming_down
          end

          event :stopped_voluming do
            transition [:voluming_up, :voluming_down] => :not_voluming
          end
        end

        class VolumeUp < Action # :nodoc:
          register :'volume-up', :output

          def request!
            source.voluming_up!
            super
          end

          def execute!
            source.stopped_voluming!
            super
          end
        end

        class VolumeDown < Action # :nodoc:
          register :'volume-down', :output

          def request!
            source.voluming_down!
            super
          end

          def execute!
            source.stopped_voluming!
            super
          end
        end

        class Complete
          class Success < Rayo::Event::Complete::Reason
            register :success, :output_complete
          end
        end
      end # Output
    end # Command
  end # Rayo
end # Punchblock