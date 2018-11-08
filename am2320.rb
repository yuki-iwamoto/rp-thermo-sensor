require 'rubygems'
require 'i2c'
require 'pry'

class AM2320

  def initialize(path, address = 0x5c)
    @device = I2C.create(path)
    @address = address
  end

  def tempature_standard_deviation(tempAry)
	actualDiffTempature = 1.62;
	#average tempature
	sumTempature = tempAry.inject(0){|result, n|result + n}
	averageTempature = if tempAry.size
		sumTempature / tempAry.size
	else
		actualDiffTempature
	end
	# 実際の温度計との差を埋める処理
	targetTempature= averageTempature - actualDiffTempature
	#targetTempature = averageTempature
	return targetTempature.round(1)
  end

  def read
    #センサーを付ける
    begin
      @device.write(@address, "")
    rescue
      #TODO いつか例外でした際の処理を決めてやる必要があり
      return nil
    end
    #センサー情報読み込み
    begin
      #x03:最低気温,x00:最高湿度,x04 情報保有
      s = @device.read(@address, 8, "\x03\x00\x04")
    rescue
      #TODO いつか例外でした際の処理を決めてやる必要があり
      return nil
    end
    #温度センサーで値が取れなかった場合、処理のやり直し
    if s.nil?
      return nil
    end
    # TODO ここの使わない変数は温度取得時に必要なのか？
    func_code, ret_len, hum_h, hum_l, temp_h, temp_l, crc_l, crc_h = s.bytes.to_a
    temp = (temp_h << 8) | temp_l
    temp = temp / 10.0
    #温度センサーで異常値を取得した場合に弾く
    if temp <= 0.0 || 100.0 <= temp
      return nil
    end
    return temp
  end
end

