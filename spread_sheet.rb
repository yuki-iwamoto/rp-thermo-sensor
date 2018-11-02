require '/home/pi/rp-thermo-sensor/am2320'
require 'date'
require 'csv'
require 'pry'
require 'fileutils'
require 'timeout'
require 'logger'
require 'dotenv'
Dotenv.load
# process start
sensor = AM2320.new('/dev/i2c-1')
nth = 5
filesize = 1024 * 10
logger = Logger.new('/var/log/thermo_senseor.log', nth, filesize)
logger.formatter = proc do |severity, datetime, progname, msg|
   "!#{severity}! [#{datetime}](#{progname}):#{msg}\n"
end

tempAry = []

begin
  logger.info("温度検査開始")
  Timeout.timeout(30) do
    while tempAry.length < 8 do
	value = sensor.read
	tempAry << value unless value.nil?
	sleep(rand(0.5..2.0))
    end  
  end
rescue Timeout::Error => e
   #Thread.kill(measure_thread)
   logger.error("温度検査時タイムアウトエラー:#{e}")
rescue => e
	logger.error("温度検査時エラーその他: Unknown(#{e})")
end
# get average tempature
if tempAry.empty?
  logger.error('温度データが１件も取得できませんでした。')
  raise Exception.new('温度データが１件も取得できませんでした。')
end
targetTempature = sensor.tempature_standard_deviation(tempAry)

#csv
time = Time.new()
Ymd = time.strftime('%Y%m%d')
Hi = time.strftime('%H:%M')
new_csv = "tempature#{Ymd}.csv"
#CSV中身読み込み
rows = []
newCsvCreateFlg = false
unless File.exist?("/home/pi/rp-thermo-sensor/#{new_csv}")
 newCsvCreateFlg = true;
end

begin
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
rescue => e
	logger.error("csv処理でエラー:#{e}")
end

#Google spreadsheet
sheet_id = ENV["SHEET_ID"]
json_file = ENV["AUTH_JSON"]


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
begin
   auth.fetch_access_token!
rescue => e
   logger.error("スプレッドシート認証エラー:#{e}")
end

# スプレッドシートの取得
begin
   session = GoogleDrive.login_with_oauth(auth.access_token)
   ws = session.spreadsheet_by_key(sheet_id).worksheets[0]
   # ヘッダー後の列に追記する
   latest_row = ws.num_rows + 1
   ws[latest_row,1] = time.strftime("%Y/%m/%d %H:%M")
   ws[latest_row,2] = targetTempature.to_s

   ws.save
rescue => e
   logger.error("スプレッドシートデータ記載時エラー:#{e}")
end
