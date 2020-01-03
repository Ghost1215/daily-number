require 'httparty'
require 'json'
require 'nokogiri'
require 'aws-sdk-dynamodb'
require 'aws-sdk'
require 'csv'
require 'open-uri'
require 'uuid'

def lambda_handler(event:, context:)

  begin
    # unexpected that this should be required to be set, but fails when it isn't
    # something about scoping in the blocks below
    blend_name, value_from_oilprice, oilprice_metrics_array, item_id_array = false, false, [], []

    uuid = UUID.new

    client_params = {region: "us-west-2"}
    client_params[:endpoint] = 'http://docker.for.mac.localhost:8000' unless ENV['AWS_SAM_LOCAL'].nil?
    dynamodb = Aws::DynamoDB::Client.new(client_params)


    # ############### Get Oilprice.com data

    oilprice_response = HTTParty.get("https://oilprice.com/")
    raise "Bad response from OilPrice" if oilprice_response.code != 200

    page = Nokogiri::HTML(oilprice_response)
    table = page.search('table').first
    table&.search('tr').each do |row|
      cells = row&.search('td')
      blend_name = cells&.search('.blend_name')&.text&.match(/^[^•]*/)[0]&.strip&.downcase

      if !blend_name.nil?
        value_from_oilprice = cells.search('.value').text.strip
        if blend_name == "wti crude"
          oilprice_metrics_array << ["WTI Crude", value_from_oilprice]
        elsif blend_name == "brent crude"
          oilprice_metrics_array << ["Brent Crude", value_from_oilprice]
        elsif blend_name == "natural gas"
          oilprice_metrics_array << ["Natural Gas", value_from_oilprice]
        end
      else
        raise "failed to get blend_name"
      end
    end

    ## Write Oilprice data to DynamoDB
    if oilprice_metrics_array.size > 0
      oilprice_metrics_array.each do |metric|
        id = uuid.generate
        item = {
          id: id,
          createdAt: "#{Time.now.strftime('%Y-%m-%dT%H:%M:%S.%L%z')}",
          metric: metric[0],
          value: metric[1],
          unit: "dollars",
        }
        params = {
            table_name: 'MetricsSnapshotsTable',
            item: item,
            return_values: "NONE"
        }
        resp = dynamodb.put_item(params)
        item_id_array << id
      end
    else
      raise "failed to find oilprice data"
    end

    # ############### Get MLO data
    mlo_csv = open('https://www.esrl.noaa.gov/gmd/webdata/ccgg/trends/co2_mlo_weekly.csv')
    csva = CSV.parse(mlo_csv, :headers=>true).to_a
    ppm = csva.last[1]
    id = uuid.generate
    mlo_item = {
      id: id,
      createdAt: "#{Time.now.strftime('%Y-%m-%dT%H:%M:%S.%L%z')}",
      metric: "PPM CO2, Mauna Loa",
      value: ppm,
      unit: "ppm",
    }
    mlo_params = {
        table_name: 'MetricsSnapshotsTable',
        item: mlo_item,
        return_values: "NONE"
    }
    resp = dynamodb.put_item(mlo_params)
    item_id_array << id




    # ######### Invoke Lambda to send email
    prod = ENV['AWS_SAM_LOCAL'].nil? ? true : false

    lambda_client_params = {region: "us-west-2"}
    lambda_client_params[:endpoint] = 'http://host.docker.internal:3001' unless prod
    client = Aws::Lambda::Client.new(lambda_client_params)

    payload_hash = {:item_ids => item_id_array.join(",")}
    payload = JSON.generate( payload_hash )
    invoke_params = {
      invocation_type: 'Event',
      log_type: 'None',
      payload: payload
    }
    invoke_params[:function_name] = prod ? 'dailyn-SendEmailFunction-4T3P4J9XB670' : 'http://host.docker.internal:3001'
    # invocation_type: "Event - Invoke the function asynchronously. Send events that fail multiple times to the function's dead-letter queue (if it's configured). The API response only includes a status code."
    resp = client.invoke( invoke_params )

    {
      statusCode: 200,
      body: {
        message: "Got WTI and added to DynamoDB",
        # location: response.body
      }.to_json
    }

  rescue HTTParty::Error => e
    puts "HTTParty fail:"
    puts e.inspect
    raise error
  rescue  Aws::DynamoDB::Errors::ServiceError => e
    puts 'Unable to add metric:'
    puts e.inspect
    raise e
  rescue => e
    puts "Generic error:"
    puts e.inspect
    raise e
  end
end
