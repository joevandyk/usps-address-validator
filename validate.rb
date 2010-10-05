require 'rubygems'
require 'json'
require 'nokogiri'
require 'open-uri'
require 'uri'

=begin
  OVERVIEW
  This is a little program that interacts with the USPS address validation API.
  You give it JSON and this will give you cleaned-up JSON.

  You will need to sign up with the USPS folks and have them give you logins.
  If you are working with their test environment, modify the SITE and API_URL constants below.

  Given this JSON string over STDIN:
    {
      "address1": "771 Encina",
      "address2": "",
      "city":     "Gilbert",
      "state":    "AZ",
      "zip":      ""
    }

   Will spit out this cleaned up JSON:
     {
       "address1": "771 E ENCINAS AVE",
       "address2": "",
       "city":     "GILBERT",
       "state":    "AZ"
       "zip":      "85234",
       "success":  true,
     }

   If USPS can't find the address, it'll output something like:
     {
       "error_message": "Address Not Found.",
       "success":       false
     }
=end

module Tanga; end
module Tanga::AddressValidator
  USPS_ID = 'XXXXXXXXXXXX'
  SITE    = 'http://production.shippingapis.com'
  API_URL = 'ShippingAPI.dll'

  # Given a JSON string w/ address1, address2, city, state, and zip,
  # Returns a USPS validated
  def self.validate input_json
    # Convert the input JSON string to a Ruby hash
    address_hash = JSON.parse(input_json)

    # Build up the USPS Web API url -- based off the address.
    usps_api_url = build_usps_api_url(address_hash)

    # Fetch the USPS XML
    xml = Nokogiri(open(usps_api_url).read)

    # Convert the USPS XML to a JSON string
    json = convert_usps_xml_to_json(xml)

    # Drink a beer in the shower.
    return json
  end

  class << self
    private

    # Given the XML returned by the USPS api, generate a pretty JSON string.
    def convert_usps_xml_to_json xml
      result = {}
      if xml.at_css('Error')
        result["success"] = false
        result["error_message"] = extract_node(xml, 'Description')
      else
        result["success"]  = true
        result["address1"] = extract_node(xml, 'Address2')
        result["address2"] = extract_node(xml, 'Address1')
        result["city"]     = extract_node(xml, 'City')
        result["state"]    = extract_node(xml, 'State')
        result["zip"]      = extract_node(xml, 'Zip5')
      end
      result.to_json
    end

    # Build up an ugly ass URL for connecting to the USPS web api
    def build_usps_api_url address_hash
      # For god knows what reason, the address1 is supposed to be for
      # apartment numbers and stuff.  And address2 is used for street
      # addresses.  Seems opposite to me?  Maybe I've just been wrong
      # all this time.
      url  = %Q(/#{API_URL}?API=Verify&XML=<AddressValidateRequest USERID="#{USPS_ID}">)
      url << %Q(<Address ID="0">)
      url << %Q(<Address1>#{address_hash["address2"]}</Address1>)
      url << %Q(<Address2>#{address_hash["address1"]}</Address2>)
      url << %Q(<City>#{address_hash["city"]}</City>)
      url << %Q(<State>#{address_hash["state"]}</State>)
      url << %Q(<Zip5>#{address_hash["zip"]}</Zip5>)
      url << %Q(<Zip4></Zip4>)
      url << %Q(</Address></AddressValidateRequest>)

      URI.escape(SITE + url)
    end

    def extract_node xml, name
      node = xml.at_css(name)
      node ? node.content.strip : ''
    end
  end
end

begin
  input_json = STDIN.read
  STDOUT.puts Tanga::AddressValidator.validate(input_json)
rescue Exception => e
  STDERR.puts e.message
  STDERR.puts "Input: #{ input_json.inspect }"
  STDERR.puts e.backtrace.inspect
  exit -1
end
