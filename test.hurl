# Test 1: Simple GET request with query params and headers
GET https://httpbin.org/get
[QueryStringParameters]
page: 1
limit: 10
[Headers]
Accept: application/json
User-Agent: Hurl-Test-Runner

# Assert HTTP status and response structure
HTTP 200
[Asserts]
status == 200
header "Content-Type" == "application/json"
jsonpath "$.args.page" == "1"
jsonpath "$.args.limit" == "10"
# Capture origin IP to use in subsequent requests
[Captures]
client_ip: jsonpath "$.origin"


# Test 2: POST request sending JSON payload and asserting returned data
POST https://httpbin.org/post
[Headers]
Content-Type: application/json
{
  "name": "Gemini",
  "client": "{{client_ip}}",
  "active": true
}

# Assert response values and duration
HTTP 200
[Asserts]
status == 200
duration < 2000
jsonpath "$.json.name" == "Gemini"
jsonpath "$.json.active" == true