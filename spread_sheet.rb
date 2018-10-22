require './am2320'
require 'google_drive'
require 'date'
require 'csv'
require 'pry'
require 'fileutils'

# process start
sensor = AM2320.new('/dev/i2c-1')

# pre process before measure tempature
#30.times {
#  sensor.read
#}

# measure tempature process
tempAry = []
# 処理を終えるかどうかフラグで管理する
#reloopFlg = true
end_time = Time.now + 20
# ５回分の温度を取得する
while Time.now < end_time do
  temp = sensor.read
  tempAry << temp unless temp.nil?
  sleep(1)
end
# get average tempature
targetTempature = sensor.tempature_standard_deviation(tempAry)
#csv
time = Time.new()
Ymd = time.strftime('%Y%m%d')
Hi = time.strftime('%H:%M')
new_csv = "tempature#{Ymd}.csv"
#CSV中身読み込み
rows = []
newCsvCreateFlg = false
unless File.exist?("/home/pi/#{new_csv}")
 newCsvCreateFlg = true;
end
#begin
#  rows= CSV.read(new_csv)
#  CSV.close_read(new_csv)
#rescue
#  newCsvCreateFlg = true
#end
#binding.pry
#rows = []
#FileUtils.chmod(0755, new_csv)
if newCsvCreateFlg
  # 今日の分新規作成
	CSV.open(new_csv,'w') do |rows|
	 rows << ["#{Ymd}"]
	 rows << ["#{Hi}"]
	 rows << ["#{targetTempature.to_s}"]
	end
else
  # 今日の分追記更新
	CSV.open(new_csv,'a') do |rows|
	 rows << ["#{Ymd}"]
	 rows << ["#{Hi}"]
	 rows << ["#{targetTempature.to_s}"]
	end
end

#Google spreadsheet
sheet_id = File.read('.gd-token')
json_file = "/home/pi/Test temperature Server room-c61a8093e3eb.json"

options = JSON.parse(File.read(json_file))
key = OpenSSL::PKey::RSA.new(options['private_key'])

auth = Signet::OAuth2::Client.new(
  token_credential_uri: options['token_uri'],
  audience: options['token_uri'],
  scope: %w(
    https://www.googleapis.com/auth/drive
    https://docs.google.com/feeds/
    https://docs.googleusercontent.com/
    https://spreadsheets.google.com/feeds/
  ),
  issuer: options['client_email'],
  signing_key: key
)
auth.fetch_access_token!

# スプレッドシートの取得
session = GoogleDrive.login_with_oauth(auth.access_token)
ws = session.spreadsheet_by_key(sheet_id).worksheets[0]
# ヘッダー後の列に追記する
latest_row = ws.num_rows + 1
ws[latest_row,1] = time.strftime("%Y/%m/%d %H:%M")
ws[latest_row,2] = targetTempature.to_s

ws.save
