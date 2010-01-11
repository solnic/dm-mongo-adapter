require File.join(File.dirname(__FILE__), 'spec_helper')

describe DataMapper::Mongo::EmbeddedModel do

  before(:all) do
    class User
      include Resource

      property :id,   ObjectID
      property :name, String
      property :age,  Integer
    end

    class Address
      include EmbeddedResource

      property :street,    String
      property :post_code, String
      property :phone,     String
    end

    class Car
      include EmbeddedResource

      property :name, String
    end

    class City
      include EmbeddedResource

      property :name, String
    end

    User.embeds 1, :address, :model => Address
    Address.embeds 1, :city, :model => City
    User.has User.n, :cars
  end

  describe "#new" do
    it "should not need a key" do
      lambda {
        class Thing
          include DataMapper::Mongo::EmbeddedResource
          property :name, String
        end

        Thing.new
      }.should_not raise_error
    end
  end

  describe "creating new resources" do
    it "should save via parent" do
      user = User.new :address => Address.new(:street => 'Blank 0', :city => City.new(:name => 'Blank City'))
      user.save.should be(true)
      user.new?.should be(false)
    end

    it "should create via parent" do
      user = User.create(:address => Address.new(:street => 'Blank 0', :city => City.new(:name => 'Blank City')))
      user.new?.should be(false)
    end

    it "should save embedded resources" do
      user = User.new :address => Address.new(:street => 'Blank 0', :city => City.new(:name => 'Blank City'))
      user.address.city.save.should be(true)
      user.address.save.should be(true)
      user.new?.should be(false)
      user.address.city.new?.should be(false)
      user.address.new?.should be(false)
    end

    it "should not allow creation of an embedded resource without a parent" do
      address = Address.new(:street => 'Blank 0')
      lambda { address.save }.should raise_error(EmbeddedResource::MissingParentError)
      city = City.new(:name => 'Blank City')
      lambda { city.save }.should raise_error(EmbeddedResource::MissingParentError)
    end
  end

  describe "updating resources" do
    before :all do
      @user = User.create(:name => 'john', :address => Address.new(:city => City.new))
    end

    it "should update embedded resource" do
      @user.update(:address => { :street => 'Something 1', :city => {:name => "Some city"}}).should be(true)

      @user.reload

      @user.address.street.should_not be_nil
      @user.address.street.should eql('Something 1')
      @user.address.should be_instance_of(Address)
      @user.address.city.should_not be_nil
      @user.address.city.name.should == "Some city"
      @user.address.city.should be_instance_of(City)
    end
  end

  describe "#dirty?" do
    before :all do
      @user = User.new
    end

    it "should return false when new" do
      address = Address.new
      address.dirty?.should be(false)
      city = City.new
      city.dirty?.should be(false)
    end

    it "should return true if changed" do
      address = Address.new(:street => "Some Street 1234")
      address.dirty?.should be(true)
      city = City.new(:name => "New York City")
      city.dirty?.should be(true)
    end

    it "should return false for a clean parent" do
      @user.dirty?.should be(false)
    end

    it "should return true with one-to-one" do
      @user.address = Address.new(:street => 'Some Street 1234')
      @user.address.city = City.new(:name => "San Francisco")
      @user.dirty?.should be(true)
      @user.address.dirty?.should be(true)
      @user.address.city.dirty?.should be(true)
    end

    it "should include embedded resource attributes in the dirty attributes list" do
      @user.address = Address.new
      @user.address.street = 'Some Street 1234'
      @user.address.city = City.new
      @user.address.city.name = 'Los Angeles'

      dirty_attributes    = @user.dirty_attributes

      dirty_attributes.should_not be_nil

      address_dirty_attrs = dirty_attributes[@user.model.embedments[:address]]

      address_dirty_attrs.should_not be_nil
      address_dirty_attrs.keys.size.should eql(1)
      address_dirty_attrs.values.include?('Some Street 1234').should be(true)
    end

    describe "with saved resource" do
      before :all do
        @user.name = 'john'
        @user.address = Address.new(:street => 'A Street 101')
        @user.save
      end

      it "should return true with one-to-many" do
        @user.cars << Car.new
        @user.dirty?.should be(true)
      end

      it "should return false with a loaded resource" do
        user = User.get(@user.id)
        user.dirty_embedments?.should be(false)
        user.dirty?.should be(false)
      end
    end
  end
end
