require "kemal"

error HTTP::FormData::Error do |env|
  env.response.status_code = 400
  "Bad Request"
end

error MIME::Multipart::Error do |env|
  env.response.status_code = 400
  "Bad Request"
end
