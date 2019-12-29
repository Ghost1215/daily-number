require 'aws-sdk'

def lambda_handler(event:, context:)
  
  begin
    
    # # Get page from Oilprice.com
    # response = HTTParty.get("https://oilprice.com/")
    # raise "Bad response from OilPrice" if response.code != 200
    #
    # # parse values from it
    # page = Nokogiri::HTML(response)
    # table = page.search('table').first
    # table.search('tr').each do |row|
    #   cells = row.search('td')
    #   blend_name = cells.search('.blend_name').text.match(/^[^•]*/)[0].strip
    #
    #   if blend_name.downcase == "wti crude"
    #     value_from_oilprice = cells.search('.value').text
    #     puts "WTI Crude: #{value_from_oilprice}"
    #
    #     # connect to DynamoDB
    #     dynamodb = Aws::DynamoDB::Client.new(
    #       region: "us-west-2",
    #       endpoint: 'http://docker.for.mac.localhost:8000',
    #     )
    #
    #     # prepare row
    #     item = {
    #       Id: "#{Time.now.to_i}",
    #       CreatedAt: "#{Time.now.strftime('%Y-%m-%dT%H:%M:%S.%L%z')}",
    #       metric: 'WTI Crude',
    #       value: value_from_oilprice,
    #     }
    #
    #     params = {
    #         table_name: 'MetricsSnapshotsTable',
    #         item: item
    #     }
    #
    #     # Write metric value to table
    #     dynamodb.put_item(params)
    #   end
    # end # end table search
    
    
    
    # create separate lambda to do the send ######################
    
    # send email with value
    sender = "john@fnnny.com"
    recipient = "john@fnnny.com"
    awsregion = "us-west-2"
    subject = "Your daily numbers"
    
    # later: put this in its own lambda. have it get all the metrics collected that day, bundle them, and send them.
    htmlbody =
      '<h1>Your daily numbers!</h1>'\
      '<p>This email was sent with <a href="https://aws.amazon.com/ses/">sas</a>.'
    textbody = '<h1>Your daily numbers!</h1>'
    encoding = "UTF-8"
    
    # Create a new SES resource and specify a region
    ses = Aws::SES::Client.new(region: awsregion)
    
    resp = ses.send_email({
      destination: {
        to_addresses: [
          recipient,
        ],
      },
      message: {
        body: {
          html: {
            charset: encoding,
            data: htmlbody,
          },
          text: {
            charset: encoding,
            data: textbody,
          },
        },
        subject: {
          charset: encoding,
          data: subject,
        },
      },
    source: sender,
    # Comment or remove the following line if you are not using 
    # a configuration set
    # configuration_set_name: configsetname,
    })
    puts "Email sent!"
    
    # end separate lambda to do the send ######################
      
    
    {
      statusCode: 200,
      body: {
        message: "Sent email",
        # location: response.body
      }.to_json
    }
    
  rescue Aws::SES::Errors::ServiceError => e
    puts "Email not sent. Error message: #{e}"
    raise e
  rescue => e
    puts "Generic error:"
    puts e.inspect
    raise e
  end
end
