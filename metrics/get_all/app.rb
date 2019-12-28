require 'httparty'
require 'json'
require 'nokogiri'
require 'aws-sdk-dynamodb'

def lambda_handler(event:, context:)
  
  begin
    response = HTTParty.get("https://oilprice.com/")
    raise "Bad response from OilPrice" if response.code != 200

    page = Nokogiri::HTML(response)
    table = page.search('table').first
    table.search('tr').each do |row|
      cells = row.search('td')
      blend_name = cells.search('.blend_name').text.match(/^[^•]*/)[0].strip
      
      if blend_name.downcase == "wti crude"
        value_from_oilprice = cells.search('.value').text
        puts "WTI Crude: #{value_from_oilprice}"

        dynamodb = Aws::DynamoDB::Client.new(
          region: "us-west-2",
          endpoint: 'http://docker.for.mac.localhost:8000',
        )

        table_name = 'MetricsSnapshotsTable'
  
        item = {
          Id: "#{Time.now.to_i}",
          CreatedAt: "#{Time.now.strftime('%Y-%m-%dT%H:%M:%S.%L%z')}",
          metric: 'WTI Crude',
          value: value_from_oilprice,
        }

        params = {
            table_name: table_name,
            item: item,
            return_values: "ALL_OLD"
        }
    
        resp = dynamodb.put_item(params)
        puts "put_item: #{resp}"
      end
    end
    
    {
      statusCode: 200,
      body: {
        message: "Got WTI and added to DynamoDB",
        # location: response.body
      }.to_json
    }
    
  rescue  Aws::DynamoDB::Errors::ServiceError => e
    puts 'Unable to add metric:'
    puts e.inspect
    raise e
  rescue HTTParty::Error => e
    puts "HTTParty fail:"
    puts e.inspect
    raise error
  rescue => e
    puts "Generic error:"
    puts e.inspect
    raise e
  end
end
