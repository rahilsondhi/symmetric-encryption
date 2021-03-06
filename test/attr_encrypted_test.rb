require File.dirname(__FILE__) + '/test_helper'

ActiveRecord::Base.logger = SemanticLogger[ActiveRecord]
ActiveRecord::Base.configurations = YAML::load(ERB.new(IO.read('test/config/database.yml')).result)
ActiveRecord::Base.establish_connection('test')

ActiveRecord::Schema.define :version => 0 do
  create_table :users, :force => true do |t|
    t.string :encrypted_bank_account_number
    t.string :encrypted_social_security_number
    t.string :encrypted_string
    t.text   :encrypted_long_string
    t.text   :encrypted_data_yaml
    t.text   :encrypted_data_json
    t.string :name

    t.string :encrypted_integer_value
    t.string :encrypted_float_value
    t.string :encrypted_decimal_value
    t.string :encrypted_datetime_value
    t.string :encrypted_time_value
    t.string :encrypted_date_value
    t.string :encrypted_true_value
    t.string :encrypted_false_value
  end
end

class User < ActiveRecord::Base
  attr_encrypted :bank_account_number
  attr_encrypted :social_security_number
  attr_encrypted :string,      :random_iv => true
  attr_encrypted :long_string, :random_iv => true, :compress => true
  attr_encrypted :data_yaml,   :random_iv => true, :compress => true, :type => :yaml
  attr_encrypted :data_json,   :random_iv => true, :compress => true, :type => :json

  attr_encrypted :integer_value,  :type => :integer
  attr_encrypted :float_value,    :type => :float
  attr_encrypted :decimal_value,  :type => :decimal
  attr_encrypted :datetime_value, :type => :datetime
  attr_encrypted :time_value,     :type => :time
  attr_encrypted :date_value,     :type => :date
  attr_encrypted :true_value,     :type => :boolean
  attr_encrypted :false_value,    :type => :boolean

  validates :encrypted_bank_account_number, :symmetric_encryption => true
  validates :encrypted_social_security_number, :symmetric_encryption => true
end

# Load Symmetric Encryption keys
SymmetricEncryption.load!(File.join(File.dirname(__FILE__), 'config', 'symmetric-encryption.yml'), 'test')

# Initialize the database connection
config_file = File.join(File.dirname(__FILE__), 'config', 'database.yml')
raise "database config not found. Create a config file at: test/config/database.yml" unless File.exists? config_file

cfg = YAML.load(ERB.new(File.new(config_file).read).result)['test']
raise("Environment 'test' not defined in test/config/database.yml") unless cfg

User.establish_connection(cfg)

#
# Unit Test for attr_encrypted and validation aspects of SymmetricEncryption
#
class AttrEncryptedTest < Test::Unit::TestCase
  context 'the SymmetricEncryption Library' do

    setup do
      @bank_account_number = "1234567890"
      @bank_account_number_encrypted = "QEVuQwIAL94ArJeFlJrZp6SYsvoOGA=="

      @social_security_number = "987654321"
      @social_security_number_encrypted = "QEVuQwIAS+8X1NRrqdfEIQyFHVPuVA=="

      @string = "A string containing some data to be encrypted with a random initialization vector"
      @long_string = "A string containing some data to be encrypted with a random initialization vector and compressed since it takes up so much space in plain text form"

      @name = 'Joe Bloggs'

      @integer_value = 12
      @float_value = 88.12345
      @decimal_value = BigDecimal.new("22.51")
      @datetime_value = DateTime.new(2001, 11, 26, 20, 55, 54, "-5")
      @time_value = Time.new(2013, 01, 01, 22, 30, 00, "-04:00")
      @date_value = Date.new(1927, 04, 02)
      @h = { :a => 'A', :b => 'B' }

      @user = User.new(
        # Encrypted Attribute
        :bank_account_number    => @bank_account_number,
        # Encrypted Attribute
        :social_security_number => @social_security_number,
        :name                   => @name,
        # data type specific fields
        :integer_value          => @integer_value,
        :float_value            => @float_value,
        :decimal_value          => @decimal_value,
        :datetime_value         => @datetime_value,
        :time_value             => @time_value,
        :date_value             => @date_value,
        :true_value             => true,
        :false_value            => false,
        :data_yaml              => @h.dup,
        :data_json              => @h.dup
      )
    end

    should "have encrypted methods" do
      assert_equal true, @user.respond_to?(:encrypted_bank_account_number)
      assert_equal true, @user.respond_to?(:bank_account_number)
      assert_equal true, @user.respond_to?(:encrypted_social_security_number)
      assert_equal true, @user.respond_to?(:social_security_number)
      assert_equal true, @user.respond_to?(:data_yaml)
      assert_equal true, @user.respond_to?(:data_json)
      assert_equal false, @user.respond_to?(:encrypted_name)
    end

    should "have unencrypted values" do
      assert_equal @bank_account_number, @user.bank_account_number
      assert_equal @social_security_number, @user.social_security_number
    end

    should "have encrypted values" do
      assert_equal @bank_account_number_encrypted, @user.encrypted_bank_account_number
      assert_equal @social_security_number_encrypted, @user.encrypted_social_security_number
    end

    should "support same iv" do
      @user.social_security_number = @social_security_number
      assert first_value = @user.social_security_number
      # Assign the same value
      @user.social_security_number = @social_security_number
      assert_equal first_value, @user.social_security_number
    end

    should "support a random iv" do
      @user.string = @string
      assert first_value = @user.encrypted_string
      # Assign the same value
      @user.string = @string.dup
      assert_equal true, first_value != @user.encrypted_string
    end

    should "support a random iv and compress" do
      @user.string = @long_string
      @user.long_string = @long_string

      assert_equal true, (@user.encrypted_long_string.length.to_f / @user.encrypted_string.length) < 0.8
    end

    should "encrypt" do
      user = User.new
      user.bank_account_number = @bank_account_number
      assert_equal @bank_account_number, user.bank_account_number
      assert_equal @bank_account_number_encrypted, user.encrypted_bank_account_number
    end

    should "allow lookups using unencrypted or encrypted column name" do
      @user.save!

      inq = User.find_by_bank_account_number(@bank_account_number)
      assert_equal @bank_account_number, inq.bank_account_number
      assert_equal @bank_account_number_encrypted, inq.encrypted_bank_account_number

      @user.delete
    end

    should "all paths should lead to the same result" do
      assert_equal @bank_account_number_encrypted, (@user.encrypted_social_security_number = @bank_account_number_encrypted)
      assert_equal @bank_account_number, @user.social_security_number
      assert_equal @bank_account_number_encrypted, @user.encrypted_social_security_number
    end

    should "all paths should lead to the same result 2" do
      assert_equal @bank_account_number, (@user.social_security_number = @bank_account_number)
      assert_equal @bank_account_number_encrypted, @user.encrypted_social_security_number
      assert_equal @bank_account_number, @user.social_security_number
    end

    should "all paths should lead to the same result, check uninitialized" do
      user = User.new
      assert_equal nil, user.social_security_number
      assert_equal @bank_account_number, (user.social_security_number = @bank_account_number)
      assert_equal @bank_account_number, user.social_security_number
      assert_equal @bank_account_number_encrypted, user.encrypted_social_security_number

      assert_equal nil, (user.social_security_number = nil)
      assert_equal nil, user.social_security_number
      assert_equal nil, user.encrypted_social_security_number
    end

    should "allow unencrypted values to be passed to the constructor" do
      user = User.new(:bank_account_number => @bank_account_number, :social_security_number => @social_security_number)
      assert_equal @bank_account_number, user.bank_account_number
      assert_equal @social_security_number, user.social_security_number
      assert_equal @bank_account_number_encrypted, user.encrypted_bank_account_number
      assert_equal @social_security_number_encrypted, user.encrypted_social_security_number
    end

    should "return encrypted attributes for the class" do
      expect = {:social_security_number=>:encrypted_social_security_number, :bank_account_number=>:encrypted_bank_account_number}
      result = User.encrypted_attributes
      expect.each_pair {|k,v| assert_equal expect[k], result[k]}
    end

    should "return encrypted keys for the class" do
      expect = [:social_security_number, :bank_account_number]
      result = User.encrypted_keys
      expect.each {|val| assert_equal true, result.include?(val)}

      # Also check encrypted_attribute?
      expect.each {|val| assert_equal true, User.encrypted_attribute?(val)}
    end

    should "return encrypted columns for the class" do
      expect = [:encrypted_social_security_number, :encrypted_bank_account_number]
      result = User.encrypted_columns
      expect.each {|val| assert_equal true, result.include?(val)}

      # Also check encrypted_column?
      expect.each {|val| assert_equal true, User.encrypted_column?(val)}
    end

    should "validate encrypted data" do
      assert_equal true, @user.valid?
      @user.encrypted_bank_account_number = '123'
      assert_equal false, @user.valid?
      assert_equal ["must be a value encrypted using SymmetricEncryption.encrypt"], @user.errors[:encrypted_bank_account_number]
      @user.encrypted_bank_account_number = SymmetricEncryption.encrypt('123')
      assert_equal true, @user.valid?
      @user.bank_account_number = '123'
      assert_equal true, @user.valid?
    end



    context "with saved user" do
      setup do
        @user.save!
      end

      teardown do
        @user.destroy
      end

      should "return correct data type before save" do
        u = User.new(:integer_value => "5")
        assert_equal 5, u.integer_value
        assert u.integer_value.kind_of?(Integer)
      end

      should "handle gsub! for non-encrypted_field" do
        @user.name.gsub!('a', 'v')
        new_name = @name.gsub('a', 'v')
        assert_equal new_name, @user.name
        @user.reload
        assert_equal new_name, @user.name
      end

      should "prevent gsub! on non-encrypted value of encrypted_field" do
        # can't modify frozen String
        assert_raises RuntimeError do
          @user.bank_account_number.gsub!('5', '4')
        end
      end

      should "revert changes on reload" do
        new_bank_account_number = '444444444'
        @user.bank_account_number = new_bank_account_number
        assert_equal new_bank_account_number, @user.bank_account_number

        # Reload User model from the database
        @user.reload
        assert_equal @bank_account_number_encrypted, @user.encrypted_bank_account_number
        assert_equal @bank_account_number, @user.bank_account_number
      end

      should "revert changes to encrypted field on reload" do
        new_bank_account_number = '111111111'
        new_encrypted_bank_account_number = SymmetricEncryption.encrypt(new_bank_account_number)
        @user.encrypted_bank_account_number = new_encrypted_bank_account_number
        assert_equal new_encrypted_bank_account_number, @user.encrypted_bank_account_number
        assert_equal new_bank_account_number, @user.bank_account_number

        # Reload User model from the database
        @user.reload
        assert_equal @bank_account_number_encrypted, @user.encrypted_bank_account_number
        assert_equal @bank_account_number, @user.bank_account_number
      end

      context "data types" do
        setup do
          @user_clone = User.find(@user.id)
        end

        context "integer values" do
          should "return correct data type" do
            assert_equal @integer_value, @user_clone.integer_value
            assert @user.clone.integer_value.kind_of?(Integer)
          end

          should "coerce data type before save" do
            u = User.new(:integer_value => "5")
            assert_equal 5, u.integer_value
            assert u.integer_value.kind_of?(Integer)
          end

          should "permit replacing value with nil" do
            @user_clone.integer_value = nil
            @user_clone.save!

            @user.reload
            assert_nil @user.integer_value
            assert_nil @user.encrypted_integer_value
          end

          should "permit replacing value" do
            new_integer_value = 98
            @user_clone.integer_value = new_integer_value
            @user_clone.save!

            @user.reload
            assert_equal new_integer_value, @user.integer_value
          end
        end

        context "float values" do
          should "return correct data type" do
            assert_equal @float_value, @user_clone.float_value
            assert @user.clone.float_value.kind_of?(Float)
          end

          should "coerce data type before save" do
            u = User.new(:float_value => "5.6")
            assert_equal 5.6, u.float_value
            assert u.float_value.kind_of?(Float)
          end

          should "permit replacing value with nil" do
            @user_clone.float_value = nil
            @user_clone.save!

            @user.reload
            assert_nil @user.float_value
            assert_nil @user.encrypted_float_value
          end

          should "permit replacing value" do
            new_float_value = 45.4321
            @user_clone.float_value = new_float_value
            @user_clone.save!

            @user.reload
            assert_equal new_float_value, @user.float_value
          end
        end

        context "decimal values" do
          should "return correct data type" do
            assert_equal @decimal_value, @user_clone.decimal_value
            assert @user.clone.decimal_value.kind_of?(BigDecimal)
          end

          should "coerce data type before save" do
            u = User.new(:decimal_value => "99.95")
            assert_equal BigDecimal.new("99.95"), u.decimal_value
            assert u.decimal_value.kind_of?(BigDecimal)
          end

          should "permit replacing value with nil" do
            @user_clone.decimal_value = nil
            @user_clone.save!

            @user.reload
            assert_nil @user.decimal_value
            assert_nil @user.encrypted_decimal_value
          end

          should "permit replacing value" do
            new_decimal_value = BigDecimal.new("99.95")
            @user_clone.decimal_value = new_decimal_value
            @user_clone.save!

            @user.reload
            assert_equal new_decimal_value, @user.decimal_value
          end
        end

        context "datetime values" do
          should "return correct data type" do
            assert_equal @datetime_value, @user_clone.datetime_value
            assert @user.clone.datetime_value.kind_of?(DateTime)
          end

          should "coerce data type before save" do
            now = Time.now
            u = User.new(:datetime_value => now)
            assert_equal now, u.datetime_value
            assert u.datetime_value.kind_of?(DateTime)
          end

          should "permit replacing value with nil" do
            @user_clone.datetime_value = nil
            @user_clone.save!

            @user.reload
            assert_nil @user.datetime_value
            assert_nil @user.encrypted_datetime_value
          end

          should "permit replacing value" do
            new_datetime_value = DateTime.new(1998, 10, 21, 8, 33, 28, "+5")
            @user_clone.datetime_value = new_datetime_value
            @user_clone.save!

            @user.reload
            assert_equal new_datetime_value, @user.datetime_value
          end
        end

        context "time values" do
          should "return correct data type" do
            assert_equal @time_value, @user_clone.time_value
            assert @user.clone.time_value.kind_of?(Time)
          end

          should "coerce data type before save" do
            now = Time.now
            u = User.new(:time_value => now)
            assert_equal now, u.time_value
            assert u.time_value.kind_of?(Time)
          end

          should "permit replacing value with nil" do
            @user_clone.time_value = nil
            @user_clone.save!

            @user.reload
            assert_nil @user.time_value
            assert_nil @user.encrypted_time_value
          end

          should "permit replacing value" do
            new_time_value = Time.new(1998, 10, 21, 8, 33, 28, "+04:00")
            @user_clone.time_value = new_time_value
            @user_clone.save!

            @user.reload
            assert_equal new_time_value, @user.time_value
          end
        end

        context "date values" do
          should "return correct data type" do
            assert_equal @date_value, @user_clone.date_value
            assert @user.clone.date_value.kind_of?(Date)
          end

          should "coerce data type before save" do
            now = Time.now
            u = User.new(:date_value => now)
            assert_equal now.to_date, u.date_value
            assert u.date_value.kind_of?(Date)
          end

          should "permit replacing value with nil" do
            @user_clone.date_value = nil
            @user_clone.save!

            @user.reload
            assert_nil @user.date_value
            assert_nil @user.encrypted_date_value
          end

          should "permit replacing value" do
            new_date_value = Date.new(1998, 10, 21)
            @user_clone.date_value = new_date_value
            @user_clone.save!

            @user.reload
            assert_equal new_date_value, @user.date_value
          end
        end

        context "true values" do
          should "return correct data type" do
            assert_equal true, @user_clone.true_value
            assert @user.clone.true_value.kind_of?(TrueClass)
          end

          should "coerce data type before save" do
            u = User.new(:true_value => "1")
            assert_equal true, u.true_value
            assert u.true_value.kind_of?(TrueClass)
          end

          should "permit replacing value with nil" do
            @user_clone.true_value = nil
            @user_clone.save!

            @user.reload
            assert_nil @user.true_value
            assert_nil @user.encrypted_true_value
          end

          should "permit replacing value" do
            new_value = false
            @user_clone.true_value = new_value
            @user_clone.save!

            @user.reload
            assert_equal new_value, @user.true_value
          end
        end

        context "false values" do
          should "return correct data type" do
            assert_equal false, @user_clone.false_value
            assert @user.clone.false_value.kind_of?(FalseClass)
          end

          should "coerce data type before save" do
            u = User.new(:false_value => "0")
            assert_equal false, u.false_value
            assert u.false_value.kind_of?(FalseClass)
          end

          should "permit replacing value with nil" do
            @user_clone.false_value = nil
            @user_clone.save!

            @user.reload
            assert_nil @user.false_value
            assert_nil @user.encrypted_false_value
          end

          should "permit replacing value" do
            new_value = true
            @user_clone.false_value = new_value
            @user_clone.save!

            @user.reload
            assert_equal new_value, @user.false_value
          end
        end

        context "JSON Serialization" do
          setup do
            # JSON Does not support symbols, so they will come back as strings
            # Convert symbols to string in the test
            @h.keys.each do |k|
              @h[k.to_s] = @h[k]
              @h.delete(k)
            end
          end

          should "return correct data type" do
            assert_equal @h, @user_clone.data_json
            assert @user.clone.data_json.kind_of?(Hash)
          end

          should "not coerce data type (leaves as hash) before save" do
            u = User.new(:data_json => @h)
            assert_equal @h, u.data_json
            assert u.data_json.kind_of?(Hash)
          end

          should "permit replacing value with nil" do
            @user_clone.data_json = nil
            @user_clone.save!

            @user.reload
            assert_nil @user.data_json
            assert_nil @user.encrypted_data_json
          end

          should "permit replacing value" do
            new_value = @h.clone
            new_value['c'] = 'C'
            @user_clone.data_json = new_value
            @user_clone.save!

            @user.reload
            assert_equal new_value, @user.data_json
          end
        end

        context "YAML Serialization" do
          should "return correct data type" do
            assert_equal @h, @user_clone.data_yaml
            assert @user.clone.data_yaml.kind_of?(Hash)
          end

          should "not coerce data type (leaves as hash) before save" do
            u = User.new(:data_yaml => @h)
            assert_equal @h, u.data_yaml
            assert u.data_yaml.kind_of?(Hash)
          end

          should "permit replacing value with nil" do
            @user_clone.data_yaml = nil
            @user_clone.save!

            @user.reload
            assert_nil @user.data_yaml
            assert_nil @user.encrypted_data_yaml
          end

          should "permit replacing value" do
            new_value = @h.clone
            new_value[:c] = 'C'
            @user_clone.data_yaml = new_value
            @user_clone.save!

            @user.reload
            assert_equal new_value, @user.data_yaml
          end
        end

      end
    end
  end
end