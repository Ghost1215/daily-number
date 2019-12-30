require 'aws-sdk'

def lambda_handler(event:, context:)

  begin

    client_params = {region: "us-west-2"}
    client_params[:endpoint] = 'http://docker.for.mac.localhost:8000' unless ENV['AWS_SAM_LOCAL'].nil?
    dynamodb = Aws::DynamoDB::Client.new(client_params)

    items = []
    event['item_ids'].split(',').each do |item_id|
      resp = dynamodb.get_item({
        key: {
          "id" => "#{item_id}",
        },
        table_name: "MetricsSnapshotsTable",
      })
      items << resp.item
    end

    # send email with value
    sender = "john@fnnny.com"
    recipient = "john@fnnny.com"
    awsregion = "us-west-2"
    subject = "Daily Numbers"

    # later: put this in its own lambda. have it get all the metrics collected that day, bundle them, and send them.
    htmlbody = '<h1>Your daily numbers</h1>'
    items.each do |item|
      htmlbody << "<div>#{item["metric"]}: #{(item['unit']=='dollars') ? '$' : ''}#{item["value"]}</a>"
    # textbody = '<h1>Your daily numbers!</h1>'
    end
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
          # text: {
          #   charset: encoding,
          #   data: textbody,
          # },
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
