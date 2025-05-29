# call_build_cache.rb

require "net/http"
require "uri"

# Flask の URL をここに正確に書く（https:// から）
uri = URI.parse("https://ai-server-f6si.onrender.com/build_cache")

# POSTリクエストを送信（空のボディ）
response = Net::HTTP.post(uri, "", { "Content-Type" => "application/json" })

puts "📡 ステータス: #{response.code}"
puts "📦 レスポンス: #{response.body}"
