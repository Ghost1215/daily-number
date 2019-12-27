require 'httparty'
require 'json'
require 'nokogiri'
require 'aws-sdk-dynamodb'

def lambda_handler(event:, context:)
  # begin
    response = HTTParty.get("https://oilprice.com/")
    raise "Bad response from OilPrice" if response.code != 200
    
    dynamodb = Aws::DynamoDB::Client.new(region: "us-west-2", endpoint: 'http://127.0.0.1:8000')
    # dynamodb = Aws::DynamoDB::Client.new(region: 'us-west-2') # non-local
    
    page = Nokogiri::HTML(response)
    table = page.search('table').first        
    table.search('tr').each do |row|
      cells = row.search('td')
      blend_name = cells.search('.blend_name').text.match(/^[^•]*/)[0].strip
      if blend_name.downcase == "wti crude"
        value = cells.search('.value').text
        puts "WTI Crude: #{value}"
        
        metric = {
            metric: 'WTI Crude',
            url: 'https://oilprice.com/',
            value: value,
            created_at: Time.now.strftime('%Y-%m-%dT%H:%M:%S.%L%z')
        }

        params = {
            table_name: 'MetricsSnapshoptsTable',
            item: metric
        }
        
        puts "about to put item"

        # begin
          dynamodb.put_item(params)
          # puts 'Added WTI Crude: ' + year.to_i.to_s + ' - ' + title
        # rescue  Aws::DynamoDB::Errors::ServiceError => error
        #   puts 'Unable to add movie:'
        #   puts error.message
        # end
        
      end
    end
    
    {
      statusCode: 200,
      body: {
        message: "When implemented this function should get all the available metricz",
        # location: response.body
      }.to_json
    }
  # rescue HTTParty::Error => e
  #   puts "PaRtY OVER"
  #   puts e.inspect
  #   raise error
  # rescue => e
  #   puts e.inspect
  #   raise e
  # end
end
