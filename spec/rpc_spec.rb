# encoding: binary

require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

require 'stringio'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "..", "lib"))
require 'protocol_buffers'
require 'protocol_buffers/compiler'

module ProtocolBuffers
  module Services

module A
  module Really
    module Deeply
      class Nested
        class Klass
        end
      end
    end
  end
end

    describe ProtocolBuffers, "RPC Services" do
      before(:each) do
        # clear our namespaces
        %w(Services).each do |klass|
          Object.send(:remove_const, klass.to_sym) if Object.const_defined?(klass.to_sym)
        end

        # load test protos
        load File.join(File.dirname(__FILE__), "proto_files", "services.pb.rb")
      end

      let(:service) {ServiceRegistry.find(::Services::FooBarService.fully_qualified_name)}
      let(:bar_request) { ::Services::BarRequest.new }
      let(:bar_response){ ::Services::BarResponse.new}
      let(:handler) {double(:get_bar => bar_response, :get_foo => "foo")}
      let(:handler_factory) { lambda {handler} }
      let(:register!) { ServiceRegistry.register_service(::Services::FooBarService.fully_qualified_name, handler_factory)}

      context ServiceRegistry do
        it "should register a handler factory with a service" do
          number_of_registered_services = ServiceRegistry.number_of_registered_services
          register!
          ServiceRegistry.number_of_registered_services.should == (number_of_registered_services + 1)
        end

        it "should register all types associated with a service that have a fully_qualified_name" do
          ServiceRegistry.to_class("services.FooResponse").should == ::Services::FooResponse
          ServiceRegistry.to_class(nil).should == nil
          ServiceRegistry.to_class("services.blah").should == nil
        end

        it "should not register a handler to a service without a fully_qualified_name" do
          ::Services::NoNameFooBarService.fully_qualified_name.should == nil
          number_of_registered_services = ServiceRegistry.number_of_registered_services
          ServiceRegistry.register_service(::Services::NoNameFooBarService.fully_qualified_name, handler_factory)
          ServiceRegistry.number_of_registered_services.should == number_of_registered_services
        end

        it "should find an instance of a service by its registration name" do
          ServiceRegistry.find(::Services::FooBarService.fully_qualified_name).should be_instance_of(::Services::FooBarService)
        end

        it "should create a new service instance with a handler instance inside" do
          handler_factory.should_receive(:call).and_call_original
          register!
          service.should be_instance_of(::Services::FooBarService)
        end

        it "should list all the services that have registered handlers" do
          ServiceRegistry.registered_services.should == ["services.FooBarService"]
        end

        it "should return the class of an object defined in a .proto file based on its fully_qualified_name" do
          ServiceRegistry.to_class('services.FooBarService').should == ::Services::FooBarService
        end
      end

      context Service do
        before do
          ServiceRegistry.register_service(::Services::FooBarService.fully_qualified_name, handler_factory)
        end

        it "should add the methods defined by the .proto file to the generated classes" do
          [:get_bar, :get_foo].each{|m| service.should respond_to(m)}
        end

        it "should delgate the service method calls to the handler" do
          handler.should_receive(:get_bar).with(bar_request.to_hash).and_return(bar_response.to_hash)
          service.get_bar(bar_request).should == bar_response
        end

        it "should raise an error if no handler is defined" do
          factory = lambda { nil }
          ServiceRegistry.register_service(::Services::FooBarService.fully_qualified_name, factory)
          expect {service.get_bar(bar_request)}.to raise_error
        end

        it "should raise an error if the wrong type is passed to the service method" do
          expect {service.get_bar("FOO")}.to raise_error(/Request Type Error/)
        end

        it "should raise an error if the wrong type returned from the handler" do
          handler_factory = lambda { double(get_bar: {stuff: "notggonna work"}) }
          ServiceRegistry.register_service(::Services::FooBarService.fully_qualified_name, handler_factory)
          expect {service.get_bar(bar_request)}.to raise_error(/undefined method/)
        end

        it "should define the request and result types for an rpc method" do
          ::Services::FooBarService.types_for(:get_bar).should == {request: ::Services::BarRequest, response: ::Services::BarResponse}
        end
      end
    end
  end
end