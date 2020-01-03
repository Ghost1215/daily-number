# Daily Numbers


Daily Numbers is an app to send an email every morning with numbers you want to see. Right now it's rock simple--it will mail one person (me! but fork and edit if you want it to be you) an email with stats related to energy and renewables:

- Current oil prices (WTI, Brent)
- Natural gas price (Henry Hub I presume). Gas and oil prices are scraped from Oilprice.com
- Daily atmospheric carbon measurements from the Mauna Loa Observatory. See the [Keeling Curve](https://en.wikipedia.org/wiki/Keeling_Curve) in action!

TODO:

- More energy stats: Lithium, gas & diesel, electricity rates, energy and renewable stocks (TSLA, FSLR, PEGI, AY).
- Other rando stats: other stocks, sports scores, weather. Countdowns to events you specify?
- Chart historical data
- Recent news from BNEF, GTM, UtilityDive, etc
- Cognito integration--let other people sign up for it
- Break into multiple Lambdas for different sources

It's implemented as a scheduled AWS Lambda, in Ruby, which scrapes the data and then fires another Lambda to send the email via SES. It sticks the data into DynamoDB for eventual graphing.

## Notes


#### sam commands:

Build the Lambda and associated assets. Use --use-container if there are platform-specific build steps, like compiling native code a la nokogiri. Though if you have dependencies that take a long time to compile, you'll save a lot of time by putting them in a layer.

`sam build --use-container`

Invoke a Lambda locally:

`sam local invoke GetMetricsFunction`

Guided deployment:

`sam deploy --guided --capabilities CAPABILITY_NAMED_IAM`

Subsequent deploy using saved values (re-run with --guided if you need to update them)

`sam deploy`

#### Create a layer for gems

Deployment is interminable if Nokogiri has to be built every time. Put that (and the rest of the gems) in a Lambda layer and it's muuuch faster.

Building the layer, in layer directory:

`mkdir ruby && mkdir ruby/gems
docker run --rm -v $PWD:/var/layer -w /var/layer \
    lambci/lambda:build-ruby2.5 \
    bundle install --path=ruby/gems`

Follow the rest of the steps [here](https://medium.com/@joshua.a.kahn/exploring-aws-lambda-layers-and-ruby-support-5510f81b4d14), and note you need to move directory to get /ruby/gems/2.5.0/...


#### DynamoDB local

Run in a container:

`docker run -p 8000:8000 amazon/dynamodb-local`

possilby useful repo showing how to connect to dynamodb local running in a container:
https://github.com/aws-samples/aws-sam-java-rest/blob/master/src/test/resources/test_environment_mac.json


##### Gotchas

- Change the Lambda timeout, the default 3s is too too low if external APIs are being hit.

- Make sure to give Lambdas the access they need with the 'Policies' section in template.yml


#### DynamoDB local CLI commands

[Useful blog post](https://github.com/ganshan/sam-dynamodb-local)

`aws dynamodb list-tables --endpoint-url http://docker.for.mac.localhost:8000/`

`aws dynamodb create-table --cli-input-json file://json/create-metrics-snapshots-table.json --endpoint-url http://localhost:8000`

`aws dynamodb describe-table --table-name MetricsSnapshotsTable --endpoint-url http://localhost:8000`

`aws dynamodb put-item --table-name MetricsSnapshotsTable --item '{ "Id": {"S": "2"}, "CreatedAt": {"S": "2019-12-27"}, "metric": {"S": "WTI Crude"}, "value": {"S": "foo"} }' --endpoint-url http://localhost:8000`

`aws dynamodb scan --table-name MetricsSnapshotsTable --endpoint-url http://localhost:8000`

`aws dynamodb delete-table --table-name MetricsSnapshotsTable --endpoint-url http://localhost:8000`

`aws cognito-idp list-users --user-pool-id us-west-2_mplqz04Vd`
https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/CognitoIdentityProvider/Client.html


### Issues with docs:

- In DynamoDB put\_item docs, it does not behave as expected:
https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/DynamoDB/Client.html#put_item-instance_method

- Building Layers for Ruby gems isn't really documented at all. Info in [this blog post](https://medium.com/@joshua.a.kahn/exploring-aws-lambda-layers-and-ruby-support-5510f81b4d14) should be added to AWS docs:

- Could not find list of AWS Managed Policies, have been having to rely on this gist:
https://gist.github.com/bernadinm/6f68bfdd015b3f3e0a17b2f00c9ea3f8
