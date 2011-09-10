module Journey
  module Path
    class Pattern
      attr_reader :spec, :requirements, :anchored

      def initialize strexp
        parser = Journey::Definition::Parser.new

        @anchored = true

        case strexp
        when String
          @spec         = parser.parse strexp
          @requirements = {}
          @separators   = "/.?"
        when Router::Strexp
          @spec         = parser.parse strexp.path
          @requirements = strexp.requirements
          @separators   = strexp.separators.join
          @anchored     = strexp.anchor
        else
          raise "wtf bro: #{strexp}"
        end

        @names          = nil
        @optional_names = nil
        @required_names = nil
      end

      def names
        @names ||= spec.find_all { |node|
          node.type == :SYMBOL || node.type == :STAR
        }.map { |n| n.children.tr(':', '') }
      end

      def required_names
        @required_names ||= names - optional_names
      end

      def optional_names
        @optional_names ||= spec.find_all { |node|
          node.type == :GROUP
        }.map { |group|
          group.find_all { |node|
            node.type == :SYMBOL || node.type == :STAR
          }
        }.flatten.map { |n| n.children.tr ':', '' }.uniq
      end

      class RegexpOffsets < Journey::Definition::Node::Visitor # :nodoc:
        attr_reader :offsets

        def initialize matchers
          @matchers      = matchers
          @capture_count = [0]
        end

        def accept node
          super
          @capture_count
        end

        def visit_SYMBOL node
          node = node.to_sym

          if @matchers.key? node
            re = /#{@matchers[node]}|/
            @capture_count.push((re.match('').length - 1) + (@capture_count.last || 0))
          else
            @capture_count << (@capture_count.last || 0)
          end
        end
      end

      class AnchoredRegexp < Journey::Definition::Node::Visitor # :nodoc:
        def initialize separator, matchers
          @separator = separator
          @matchers  = matchers
          @separator_re = "([^#{separator}]+)"
          super()
        end

        def visit_PATH node
          %r{\A#{node.children.map { |x| accept x }.join}\Z}
        end

        def visit_SLASH node
          "/" + node.children.map { |x| accept x }.join
        end

        def visit_SYMBOL node
          node = node.to_sym

          return @separator_re unless @matchers.key? node

          re = @matchers[node]
          # FIXME: is the question mark needed?
          "(#{re}?)"
        end

        def visit_GROUP node
          "(?:#{node.children.map { |x| accept x }.join})?"
        end

        def visit_LITERAL node
          node.children
        end

        def visit_DOT node
          '\.' + node.children.map { |x| accept x }.join
        end

        def visit_STAR node
          "(.+)"
        end
      end

      class UnanchoredRegexp < AnchoredRegexp # :nodoc:
        def visit_PATH node
          %r{\A#{node.children.map { |x| accept x }.join}}
        end
      end

      class Matcher < Journey::Definition::Node::Visitor # :nodoc:
        class SyntaxError < ::SyntaxError
          def initialize expected, actual, pos, after
            super("unexpected '#{actual}', expected '#{expected}' at #{pos} after #{after}")
          end
        end

        def initialize scanner
          @scanner = scanner
          @contents = {}
          super()
        end

        def accept node
          return @contents if @scanner.eos?
          super
          @contents
        end

        def visit_SLASH node
          token, text = @scanner.next_token
          unless token == :SLASH
            raise SyntaxError.new('/', text, @scanner.pos, @scanner.pre_match)
          end
          super
        end

        def visit_SYMBOL node
          _, text = @scanner.next_token
          @contents[node.to_sym] = text
          super
        end

        def visit_LITERAL node
          _, text = @scanner.next_token
          raise unless text == node.children
          super
        end

        def visit_DOT node
          token, text = @scanner.next_token
          unless token == node.type
            raise SyntaxError.new('.', text, @scanner.pos, @scanner.pre_match)
          end
          super
        end
      end

      class MatchData
        attr_reader :names

        def initialize names, offsets, match
          @names   = names
          @offsets = offsets
          @match   = match
        end

        def captures
          (length - 1).times.map { |i| self[i + 1] }
        end

        def [] x
          idx = @offsets[x - 1] + x
          @match[idx]
        end

        def length
          @offsets.length
        end

        def post_match
          @match.post_match
        end

        def to_s
          @match.to_s
        end
      end

      def match other
        return unless match = to_regexp.match(other)
        MatchData.new names, offsets, match
      end
      alias :=~ :match

      def source
        to_regexp.source
      end

      private
      def to_regexp
        viz = regexp_visitor.new(@separators, @requirements)
        viz.accept spec
      end

      def regexp_visitor
        @anchored ? AnchoredRegexp : UnanchoredRegexp
      end

      def offsets
        viz = RegexpOffsets.new @requirements
        viz.accept spec
      end
    end
  end
end
