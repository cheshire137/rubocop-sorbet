# frozen_string_literal: true

require "spec_helper"

RSpec.describe(RuboCop::Cop::Sorbet::MethodsShouldHaveSignatures, :config) do
  def expected_message(method:, file_path: RuboCop::Cop::Sorbet::MethodsShouldHaveSignatures::DEFAULT_FILE_PATH)
    "Methods should have Sorbet signatures. Please add a `sig` to method ##{method}. You can use `rubocop " \
      "-a --only Sorbet/MethodsShouldHaveSignatures #{file_path}` to get a starting signature you can modify. " \
      "See #{RuboCop::Cop::Sorbet::MethodsShouldHaveSignatures::DOCS_URL} for more information."
  end

  let(:config) do
    RuboCop::Config.new({ "GitHub/MethodsShouldHaveSignatures" => { "LineLengthLimit" => 118 } })
  end

  it "finds offense in method without signature when class extends T::Sig" do
    source = <<~RUBY
      # typed: true

      class FakeController
        extend T::Sig

        def foo
        ^^^^^^^ #{expected_message(method: "foo")}
          "some value"
        end
      end
    RUBY
    expect_offense(source)

    expected_corrected_source = <<~RUBY
      # typed: true

      class FakeController
        extend T::Sig

        sig { returns(T.untyped) }
        def foo
          "some value"
        end
      end
    RUBY
    expect_correction(expected_corrected_source)
  end

  it "finds offense in method without signature when class does not extend T::Sig" do
    source = <<~RUBY
      # typed: true

      class FakeController
        def foo
        ^^^^^^^ #{expected_message(method: "foo")}
          "some value"
        end
      end
    RUBY
    expect_offense(source)

    expected_corrected_source = <<~RUBY
      # typed: true

      class FakeController
        extend T::Sig

        sig { returns(T.untyped) }
        def foo
          "some value"
        end
      end
    RUBY
    expect_correction(expected_corrected_source)
  end

  it "finds offense in memoized method without signature" do
    file_path = File.expand_path(__FILE__)
    allow_any_instance_of(Parser::Source::Buffer).to receive(:name).and_return(file_path)
    source = <<~RUBY
      # typed: true

      class MyComponent
        memoize def my_expensive_method
                ^^^^^^^^^^^^^^^^^^^^^^^ #{expected_message(method: "my_expensive_method", file_path: file_path)}
          make_some_database_queries
        end
      end
    RUBY
    expect_offense(source)

    expected_corrected_source = <<~RUBY
      # typed: true

      class MyComponent
        extend T::Sig

        sig { returns(T.untyped) }
        memoize def my_expensive_method
          make_some_database_queries
        end
      end
    RUBY
    expect_correction(expected_corrected_source)
  end

  it "finds offense in memoized method requiring a multi-line signature" do
    source = <<~RUBY
      # typed: true

      class MyComponent
        memoize def my_long_expensive_method_that_is_very_verbose(unwieldy_argument_name_the_first, flag2:, flag3:, flag4: [])
                ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{expected_message(method: "my_long_expensive_method_that_is_very_verbose")}
          make_some_database_queries
        end
      end
    RUBY
    expect_offense(source)

    expected_corrected_source = <<~RUBY
      # typed: true

      class MyComponent
        extend T::Sig

        sig do
          params(
            unwieldy_argument_name_the_first: T.untyped,
            flag2: T.untyped,
            flag3: T.untyped,
            flag4: T.untyped
          ).returns(T.untyped)
        end
        memoize def my_long_expensive_method_that_is_very_verbose(unwieldy_argument_name_the_first, flag2:, flag3:, flag4: [])
          make_some_database_queries
        end
      end
    RUBY
    expect_correction(expected_corrected_source)
  end

  it "finds offense in method without signature with arguments" do
    source = <<~RUBY
      # typed: true

      class MyClass
        extend T::Sig

        def foo(bar, baz:, val: true)
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{expected_message(method: "foo")}
          "some value"
        end
      end
    RUBY
    expect_offense(source)

    expected_corrected_source = <<~RUBY
      # typed: true

      class MyClass
        extend T::Sig

        sig { params(bar: T.untyped, baz: T.untyped, val: T.untyped).returns(T.untyped) }
        def foo(bar, baz:, val: true)
          "some value"
        end
      end
    RUBY
    expect_correction(expected_corrected_source)
  end

  it "finds offense in method without signature with double parens for arguments" do
    source = <<~RUBY
      # typed: true

      def build_query((name, period, query_params))
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{expected_message(method: "build_query")}
        :some_value
      end
    RUBY
    expect_offense(source)

    expected_corrected_source = <<~RUBY
      # typed: true

      sig { params(name: T.untyped, period: T.untyped, query_params: T.untyped).returns(T.untyped) }
      def build_query((name, period, query_params))
        :some_value
      end
    RUBY
    expect_correction(expected_corrected_source)
  end

  it "finds offense in method without signature with long name and arguments" do
    source = <<~RUBY
      # typed: true

      class MyClass
        module SomeInterestingConcern
          extend T::Sig

          def you_wont_believe_how_long_this_method_is(arg0:, arg1:, arg2: true, arg3: false, arg4: [], arg5: nil)
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ #{expected_message(method: "you_wont_believe_how_long_this_method_is")}
            "some value"
          end
        end
      end
    RUBY
    expect_offense(source)

    expected_corrected_source = <<~RUBY
      # typed: true

      class MyClass
        module SomeInterestingConcern
          extend T::Sig

          sig do
            params(
              arg0: T.untyped,
              arg1: T.untyped,
              arg2: T.untyped,
              arg3: T.untyped,
              arg4: T.untyped,
              arg5: T.untyped
            ).returns(T.untyped)
          end
          def you_wont_believe_how_long_this_method_is(arg0:, arg1:, arg2: true, arg3: false, arg4: [], arg5: nil)
            "some value"
          end
        end
      end
    RUBY
    expect_correction(expected_corrected_source)
  end

  it "finds offense in method without signature in module" do
    source = <<~RUBY
      # typed: true

      module SomeHelper
        def fancy_method?
        ^^^^^^^^^^^^^^^^^ #{expected_message(method: "fancy_method?")}
          true
        end
      end
    RUBY
    expect_offense(source)

    expected_corrected_source = <<~RUBY
      # typed: true

      module SomeHelper
        extend T::Sig

        sig { returns(T.untyped) }
        def fancy_method?
          true
        end
      end
    RUBY
    expect_correction(expected_corrected_source)
  end

  it "finds offense in method without signature without parent" do
    source = <<~RUBY
      # typed: true

      def foo
      ^^^^^^^ #{expected_message(method: "foo")}
        "some value"
      end
    RUBY
    expect_offense(source)

    expected_corrected_source = <<~RUBY
      # typed: true

      sig { returns(T.untyped) }
      def foo
        "some value"
      end
    RUBY
    expect_correction(expected_corrected_source)
  end

  it "does not find offense in method without signature in strictly typed file" do
    source = %q(
      # typed: strict

      class FakeController
        def foo
          "some value"
        end
      end
    )
    refute_offended(cop, source)
  end

  it "does not find offense in method with signature" do
    source = %q(
      # typed: true

      class FakeController
        extend T::Sig

        sig { returns String }
        def foo
          "some value"
        end
      end
    )
    refute_offended(cop, source)
  end

  it "does not find offense in delegate without signature" do
    source = %q(
      # typed: true

      class FakeController
        extend T::Sig

        delegate :foo, to: :bar
      end
    )
    refute_offended(cop, source)
  end
end
