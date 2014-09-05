require "rails_helper"

describe MagicLamp do
  before do
    subject.registered_fixtures = {}
  end

  after do
    subject.registered_fixtures = {}
  end

  context "attr_accessor" do
    it { should respond_to :registered_fixtures }
    it { should respond_to :registered_fixtures= }
  end

  context "aliases" do
    let(:register_fixture) { subject.method(:register_fixture) }

    it "rub is the same as register_fixture" do
      expect(subject.method(:rub)).to eq(register_fixture)
    end

    it "wish is the same as register_fixture" do
      expect(subject.method(:wish)).to eq(register_fixture)
    end
  end

  describe "#register_fixture" do
    let(:fixture_name) { "foo" }
    let(:controller_class) { "doesn't matter here" }
    let(:block) { Proc.new { "so?" } }

    it "caches the controller class and block" do
      subject.register_fixture(controller: controller_class, name: fixture_name, &block)
      expect(subject.registered_fixtures[fixture_name]).to eq([controller_class, block])
    end

    it "raises an error without a block" do
      expect do
        subject.register_fixture(controller: controller_class, name: fixture_name)
      end.to raise_error(MagicLamp::ArgumentError, /requires a block/)
    end

    context "defaults" do
      let(:at_index) { subject.registered_fixtures["index"] }

      it "uses ApplicationController as the default controller" do
        subject.register_fixture { render :index }
        expect(at_index.first).to eq(::ApplicationController)
      end

      context "fixture name" do
        it "raises an error if the fixture is already registered by that name" do
          subject.register_fixture { render :index }
          expect do
            subject.register_fixture { render :index }
          end.to raise_error(MagicLamp::AlreadyRegisteredFixtureError, "a fixture called 'index' has already been registered")
        end

        context "ApplicationController" do
          it "uses the first argument to render when given 2" do
            render_block = Proc.new { render :index, foo: :bar }
            subject.register_fixture(controller: ::ApplicationController, &render_block)

            expect(at_index).to eq([::ApplicationController, render_block])
          end

          it "uses the only argument when it isn't a hash" do
            render_block = Proc.new { render :index }
            subject.register_fixture(controller: ::ApplicationController, &render_block)
            expect(at_index).to eq([::ApplicationController, render_block])
          end

          context "1 hash argument" do
            it "raises an error if it can't figure out a default name" do
              expect do
                subject.register_fixture(controller: ::ApplicationController) { render collection: [1, 2, 3] }
              end.to raise_error(MagicLamp::AmbiguousFixtureNameError, /Unable to infer fixture name/)
            end

            it "uses the name at the template key" do
              render_block = Proc.new { render template: :index }
              subject.register_fixture(controller: ::ApplicationController, &render_block)
              expect(at_index).to eq([::ApplicationController, render_block])
            end

            it "uses the name at the partial key" do
              render_block = Proc.new { render partial: :index }
              subject.register_fixture(controller: ::ApplicationController, &render_block)
              expect(at_index).to eq([::ApplicationController, render_block])
            end
          end
        end

        context "other controller" do
          it "prepends the controller's name to the fixture_name" do
            render_block = Proc.new { render partial: :index }
            subject.register_fixture(controller: OrdersController, &render_block)
            expect(subject.registered_fixtures["orders/index"]).to eq([OrdersController, render_block])
          end

          it "does not prepend the controller's name when it is already the beginning of the string" do
            render_block = Proc.new { render partial: "orders/order" }
            subject.register_fixture(controller: OrdersController, &render_block)
            expect(subject.registered_fixtures["orders/orders/order"]).to be_nil
            expect(subject.registered_fixtures["orders/order"]).to eq([OrdersController, render_block])
          end
        end
      end
    end
  end

  describe "#load_config" do
    it "loads the magic lamp config file" do
      expect(subject).to receive(:registered_fixtures)
      subject.load_config
    end
  end

  describe "#load_lamp_files" do
    it "loads all lamp files" do
      subject.load_lamp_files
      expect(subject.registered_fixtures["orders/foo"]).to be_an(Array)
    end

    it "blows out registered_fixtures on each call" do
      old_registry = subject.registered_fixtures
      subject.load_lamp_files
      expect(subject.registered_fixtures).to_not equal(old_registry)

      old_registry = subject.registered_fixtures
      subject.load_lamp_files
      expect(subject.registered_fixtures).to_not equal(old_registry)
    end
  end

  describe "#registered?" do

    it "returns true if the fixture is registered" do
      subject.registered_fixtures["foo"] = :something
      expect(subject.registered?("foo")).to eq(true)
    end

    it "returns false if the fixture is not registered" do
      expect(subject.registered?("bar")).to eq(false)
    end
  end

  describe "#generate_fixture" do
    let(:block) { Proc.new { render :foo } }

    before do
      subject.registered_fixtures["foo_test"] = [OrdersController, block]
    end

    it "returns the template" do
      expect(subject.generate_fixture("foo_test")).to eq("foo\n")
    end

    it "raises an error when told to generate a template that is not registered" do
      expect do
        subject.generate_fixture("brokenture")
      end.to raise_error(MagicLamp::UnregisteredFixtureError, /is not a registered fixture/)
    end
  end

  describe "#generate_all_fixtures" do
    let!(:result) { subject.generate_all_fixtures }
    let(:foo_fixture) { result["orders/foo"] }
    let(:bar_fixture) { result["orders/bar"] }
    let(:form_fixture) { result["orders/form"] }

    it "returns a hash of all registered fixtures" do
      expect(foo_fixture).to eq("foo\n")
      expect(bar_fixture).to eq("bar\n")
      expect(form_fixture).to match(/<div class="actions"/)
    end
  end

  describe "#path" do
    context "spec directory" do
      let(:spec_path) { Rails.root.join("spec") }

      it "returns a default path starting from spec" do
        expect(subject.path).to eq(spec_path)
      end
    end

    context "no spec directory" do
      let(:test_path) { Rails.root.join("test") }

      it "returns a default path starting from test" do
        allow(Dir).to receive(:exist?).and_return(false)
        expect(subject.path).to eq(test_path)
      end
    end
  end
end
