require 'aws-sdk'

def lambda_handler(event:, context:)

  puts "starting..."
  begin
    awsregion = "us-west-2"

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

    ############### GET ALL PEOPLE TO EMAIL

    puts "-----------> createing client..."
    client = Aws::CognitoIdentityProvider::Client.new(region: awsregion)
    puts "-----------> client created..."


    resp = client.list_users({
      user_pool_id: "us-west-2_mplqz04Vd", # required
      attributes_to_get: ["email"], # others: sub, user_create_date, user_last_modified_date, enabled, user_status, mfa_optional
      limit: 10,
     #  pagination_token: "SearchPaginationTokenType",
     #  filter: "UserFilterType",
    })

    puts "got client, looking at users:------> "
    resp.users.each do |user|
      # puts "user-------> #{user.inspect}"
      # puts "user.username-------> #{user.username}"
      # puts "user.user_create_date-------> #{user.user_create_date}"
      # puts "user.enabled-------> #{user.enabled?}"
      # puts "user.username-------> #{user.username}"


      puts "user.attributes[0].value -------> #{user.attributes[0].value}"
      recipient_email = user.attributes[0].value

      sender = "john@fnnny.com"
      recipient = recipient_email
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


    end





    {
      statusCode: 200,
      body: {
        message: "Sent email",
        # location: response.body
      }.to_json
    }
  rescue Aws::CognitoIdentity::Errors::ServiceError => e
    puts "Cognito error. Error message: #{e}"
    raise e
  rescue Aws::SES::Errors::ServiceError => e
    puts "Email not sent. Error message: #{e}"
    raise e
  rescue => e
    puts "Generic error:"
    puts e.inspect
    raise e
  end
end
