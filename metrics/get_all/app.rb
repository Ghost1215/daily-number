require 'httparty'
require 'json'
require 'nokogiri'
require 'aws-sdk-dynamodb'
require 'aws-sdk'

def lambda_handler(event:, context:)
  
  begin
    
    # Get page from Oilprice.com
    response = HTTParty.get("https://oilprice.com/")
    raise "Bad response from OilPrice" if response.code != 200

    # parse values from it
    page = Nokogiri::HTML(response)
    table = page.search('table').first
    table.search('tr').each do |row|
      cells = row.search('td')
      blend_name = cells.search('.blend_name').text.match(/^[^•]*/)[0].strip
      
      if blend_name.downcase == "wti crude"
        value_from_oilprice = cells.search('.value').text
        puts "WTI Crude: #{value_from_oilprice}"
        
        client_params = {region: "us-west-2"}
        client_params[:endpoint] = 'http://docker.for.mac.localhost:8000' unless ENV['AWS_SAM_LOCAL'].nil?
        dynamodb = Aws::DynamoDB::Client.new(client_params)
        
        # prepare row
        item = {
          id: "#{Time.now.to_i}",
          createdAt: "#{Time.now.strftime('%Y-%m-%dT%H:%M:%S.%L%z')}",
          metric: 'WTI Crude',
          value: value_from_oilprice,
        }
        
        params = {
            table_name: 'MetricsSnapshotsTable',
            item: item
        }
        
        # Write metric value to table
        dynamodb.put_item(params)          
      end
    end # end table search
    
    
    
    
    lambda_client_params = {region: "us-west-2"}
    lambda_client_params[:endpoint] = 'http://host.docker.internal:3001' unless ENV['AWS_SAM_LOCAL'].nil?

    client = Aws::Lambda::Client.new(lambda_client_params)
    req_payload = {:metricId => 1} # this should pass an array of hashes of metric id's and types
    payload = JSON.generate(req_payload)

    # invocation_type: "Event - Invoke the function asynchronously. Send events that fail multiple times to the function's dead-letter queue (if it's configured). The API response only includes a status code."
    resp = client.invoke({
             function_name: 'dailyn-SendEmailFunction-4T3P4J9XB670',
             invocation_type: 'Event',
             log_type: 'None',
             payload: payload
           })
    
    
    
    
    # # create separate lambda to do the send ######################
    #
    # # send email with value
    # sender = "john@fnnny.com"
    # recipient = "john@fnnny.com"
    # awsregion = "us-west-2"
    # subject = "Your daily numbers"
    #
    # # later: put this in its own lambda. have it get all the metrics collected that day, bundle them, and send them.
    # htmlbody =
    #   '<h1>Your daily numbers!</h1>'\
    #   '<p>This email was sent with <a href="https://aws.amazon.com/ses/">sas</a>.'
    # textbody = '<h1>Your daily numbers!</h1>'
    # encoding = "UTF-8"
    #
    # # Create a new SES resource and specify a region
    # ses = Aws::SES::Client.new(region: awsregion)
    #
    # resp = ses.send_email({
    #   destination: {
    #     to_addresses: [
    #       recipient,
    #     ],
    #   },
    #   message: {
    #     body: {
    #       html: {
    #         charset: encoding,
    #         data: htmlbody,
    #       },
    #       text: {
    #         charset: encoding,
    #         data: textbody,
    #       },
    #     },
    #     subject: {
    #       charset: encoding,
    #       data: subject,
    #     },
    #   },
    # source: sender,
    # # Comment or remove the following line if you are not using
    # # a configuration set
    # # configuration_set_name: configsetname,
    # })
    # puts "Email sent!"
    #
    # # end separate lambda to do the send ######################
      
    
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
  # rescue Aws::SES::Errors::ServiceError => e
  #   puts "Email not sent. Error message: #{e}"
  #   raise e
  rescue => e
    puts "Generic error:"
    puts e.inspect
    raise e
  end
end
