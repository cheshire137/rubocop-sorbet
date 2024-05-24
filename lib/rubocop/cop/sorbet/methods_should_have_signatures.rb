# typed: true
# frozen_string_literal: true

require "rubocop"

module RuboCop
  module Cop
    module Sorbet
      class MethodsShouldHaveSignatures < Base
        extend AutoCorrector
        extend T::Sig

        DOCS_URL = "https://sorbet.org/docs/sigs"
        MESSAGE = "Methods should have Sorbet signatures. Please add a `sig` to method #%s. You can use " \
          "`rubocop -a --only #{cop_name} %s` to get a starting signature you can modify. See #{DOCS_URL} for " \
          "more information."
        TYPED_TRUE_REGEX = /\A#\s*typed:\s*true\z/
        TYPED_STRICT_REGEX = /\A#\s*typed:\s*strict\z/
        ONE_INDENT_LEVEL = "  "
        DEFAULT_FILE_PATH = "<file path>"

        def_node_matcher :extend_t_sig_call?, "(send _ :extend (const (const _ :T) :Sig))"
        def_node_matcher :sig_block?, "(block (send nil? :sig) ...)"

        sig { params(def_node: RuboCop::AST::DefNode).void }
        def on_def(def_node)
          # If the file is strictly typed and missing some method signatures, the Sorbet type checker will detect
          # that. This cop doesn't need to.
          return if strict_sorbet_typing?

          t_sig_extended = does_node_extend_t_sig?(def_node.parent)

          if (t_sig_extended || sorbet_typing_enabled?) && !method_has_signature?(def_node)
            add_offense(def_node, message: offense_message_for(def_node)) do |corrector|
              autocorrector_to_add_sig(def_node).call(corrector)
              autocorrector_to_extend_t_sig(def_node).call(corrector) unless t_sig_extended
            end
          end
        end

        private

        sig { params(def_node: RuboCop::AST::DefNode).returns(String) }
        def offense_message_for(def_node)
          file_path = file_path_for(def_node)
          MESSAGE % [def_node.method_name, file_path]
        end

        sig { params(node: RuboCop::AST::Node).returns(String) }
        def file_path_for(node)
          result = node.loc.name.source_buffer.name
          return DEFAULT_FILE_PATH unless File.exist?(result)
          result
        end

        # Private: Does the given node include within it an `extend T::Sig` call?
        sig { params(node: T.nilable(RuboCop::AST::Node)).returns(T::Boolean) }
        def does_node_extend_t_sig?(node)
          return false unless node
          node.child_nodes.any? { |child_node| extend_t_sig_call?(child_node) }
        end

        sig { params(def_node: RuboCop::AST::DefNode).returns(T.nilable(T::Boolean)) }
        def method_has_signature?(def_node)
          parent = def_node.parent
          return false unless parent

          preceding_node = parent.children[parent.children.index(def_node) - 1]
          sig_block?(preceding_node)
        end

        sig { returns T::Boolean }
        def sorbet_typing_enabled?
          comments = T.let(processed_source.comments, T::Array[Parser::Source::Comment])
          comments.any? { |comment| comment.text =~ TYPED_TRUE_REGEX }
        end

        sig { returns T::Boolean }
        def strict_sorbet_typing?
          comments = T.let(processed_source.comments, T::Array[Parser::Source::Comment])
          comments.any? { |comment| comment.text =~ TYPED_STRICT_REGEX }
        end

        sig do
          params(def_node: RuboCop::AST::DefNode).returns(T.proc.params(corrector: RuboCop::Cop::Corrector).void)
        end
        def autocorrector_to_add_sig(def_node)
          line_length_limit = cop_config["LineLengthLimit"]
          ->(corrector) do
            corrector = T.let(corrector, RuboCop::Cop::Corrector)
            node_to_follow_sig = node_to_follow_sig_for(def_node)
            indentation = indentation_for(def_node)
            arg_list = def_node.arguments.argument_list.flatten.map { |arg| "#{arg.name}: T.untyped" }
            params_clause = "params(#{arg_list.join(", ")})." if arg_list.present?
            return_clause = "returns(T.untyped)"
            one_line_signature = "sig { #{params_clause}#{return_clause} }"

            correction = if line_length_limit.nil? || indentation.size + one_line_signature.size <= line_length_limit
              one_line_signature
            else
              params_clause = if arg_list.present?
                joiner = ",\n#{indentation}#{ONE_INDENT_LEVEL}#{ONE_INDENT_LEVEL}"
                "params(\n" \
                  "#{indentation}#{ONE_INDENT_LEVEL}#{ONE_INDENT_LEVEL}#{arg_list.join(joiner)}\n" \
                  "#{indentation}#{ONE_INDENT_LEVEL})."
              end
              "sig do\n#{indentation}#{ONE_INDENT_LEVEL}#{params_clause}#{return_clause}\n#{indentation}end"
            end

            corrector.insert_before(node_to_follow_sig.loc.expression, "#{correction}\n#{indentation}")
          end
        end

        sig do
          params(def_node: RuboCop::AST::DefNode).returns(T.proc.params(corrector: RuboCop::Cop::Corrector).void)
        end
        def autocorrector_to_extend_t_sig(def_node)
          ->(corrector) do
            corrector = T.let(corrector, RuboCop::Cop::Corrector)
            container = T.let(
              def_node.each_ancestor(:class, :module).first,
              T.nilable(T.any(RuboCop::AST::ClassNode, RuboCop::AST::ModuleNode))
            )

            if container&.body
              indentation = indentation_for(def_node)
              corrector.insert_before(container.body, "extend T::Sig\n\n#{indentation}")
            end
          end
        end

        # Private: Returns the node that should directly follow the Sorbet `sig` for a method.
        sig { params(def_node: RuboCop::AST::DefNode).returns(RuboCop::AST::Node) }
        def node_to_follow_sig_for(def_node)
          if def_node.parent&.send_type? # e.g., `memoize def foo`
            def_node.parent
          else
            def_node
          end
        end

        # Private: Returns a string of indentation to precede a method when correcting its lack of signature.
        sig { params(def_node: RuboCop::AST::DefNode).returns(String) }
        def indentation_for(def_node)
          node_to_follow_sig = node_to_follow_sig_for(def_node)
          total_spaces_before = def_node.source_range.column

          if def_node.parent&.send_type? # e.g., `memoize def foo`
            total_spaces_before = node_to_follow_sig.source_range.column
          end

          " " * total_spaces_before
        end
      end
    end
  end
end
