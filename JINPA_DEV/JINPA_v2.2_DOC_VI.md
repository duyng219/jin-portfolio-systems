# JINPA v2.2 - Tai lieu van hanh nhanh

JINPA v2.2 la EA ho tro giao dich thu cong theo Price Action. EA khong tu vao lenh theo tin hieu indicator; trader chon setup tren panel va bam nut de dat lenh. Phan tu dong chinh cua EA la tinh lot, gan comment setup, tinh SL theo ATR/fixed, quan ly pending order, theo doi daily drawdown va trailing stop theo ATR.

## 1. Luong hoat dong cua EA

Khi khoi dong, EA:

- Kiem tra Terminal va EA co duoc phep trade hay khong.
- Khoi tao MA va ATR theo input.
- Tao panel `JINPA v2.2` tren chart.
- Gan panel voi symbol hien tai, magic number, risk manager, position manager va trade engine.

Moi tick, EA:

- Refresh MA va ATR.
- Tinh `atrSL = ATR[1] x ATRFactor` de dat SL va trailing SL.
- Tinh `atrPO = ATR[0] x ATRFactorPO` de dat khoang cach pending order.
- Cap nhat daily drawdown.
- Neu `MaxDrawdownDaily > 0` va drawdown ngay cham nguong, panel se bi halt va khong cho dat lenh moi.
- Cap nhat panel/log.
- Goi trailing stop cho tat ca position cung symbol va magic number.

## 2. Panel setup

### SETUP

`Setup` la nhom comment chinh gan vao lenh. Cac gia tri hien co:

- `bres-pma`
- `bres-pmb`
- `bres-pmb-st`
- `revs-ppf`
- `revs-pps`
- `revs-pmr`
- `revs-pmr-st`
- `revs-pfb`
- `none`

`Key` la hau to cua comment:

- `_0_`
- `_1_`
- `_bias_`

O custom ben duoi se noi them vao cuoi comment neu co nhap noi dung. Vi du:

- Setup: `revs-ppf`
- Key: `_0_`
- Custom: `xau`
- Comment vao lenh: `revs-ppf_0_xau`

Mac dinh panel dang select setup index 3, tuc `revs-ppf`, va key `_0_`.

### ORDER SIZE / RISK

`Risk-m` chon cach tinh lot:

- `min Lot`: vao lot toi thieu cua symbol.
- `min/eq`: `Equity / MinLotPerEquitySteps x lot toi thieu`.
- `fixed`: dung dung `FixedVolume`.
- `fixed/eq`: `Equity / MinLotPerEquitySteps x FixedVolume`.
- `eq risk %`: tinh lot theo phan tram risk tren Equity va khoang cach SL.

`SL` chon cach dat stop loss:

- `atr`: SL cach gia vao lenh mot khoang `ATR x ATRFactor`.
- `fixed`: SL cach gia vao lenh `slPointsValue x _Point`. Neu `slPointsValue = 0` hoac khoang fixed khong hop le, EA fallback ve ATR khi tinh lot.

Luu y: Neu lot tinh ra nho hon lot toi thieu cua broker, EA se clamp len lot toi thieu. Khi do risk thuc te co the cao hon muc `RiskPercent`.

### TRADE

Cac nut dat lenh:

- `Buy Market`: mua tai Ask, SL nam duoi gia vao.
- `Sell Market`: ban tai Bid, SL nam tren gia vao.
- `B-Stop`: dat Buy Stop tai `Ask + atrPO`, SL tai `poPrice - atrSL`.
- `S-Stop`: dat Sell Stop tai `Bid - atrPO`, SL tai `poPrice + atrSL`.
- `B-Limit`: dat Buy Limit tai `Bid - atrPO`, SL tai `poPrice - atrSL`.
- `S-Limit`: dat Sell Limit tai `Ask + atrPO`, SL tai `poPrice + atrSL`.

Pending order het han sau `POExpirationMinutes` phut.

### CANCEL

Cac nut huy/dong lenh chi xu ly lenh cung symbol hien tai va cung `MagicNumber`:

- `xBO`: xoa tat ca Buy Stop va Buy Limit.
- `xSO`: xoa tat ca Sell Stop va Sell Limit.
- `xBuy`: dong tat ca position BUY.
- `xSell`: dong tat ca position SELL.

### TRADES LOG va EXPORT CSV

`TRADES LOG` quet cac position dang mo cua symbol + magic hien tai, hien thi ticket, comment va gio vao lenh. Log refresh moi 3 giay.

`EXPORT CSV` xuat danh sach position dang mo ra `MQL5/Files/` voi ten dang:

```text
JINPA_v2.2_<SYMBOL>_<YYYY-MM-DD>.csv
```

## 3. Trailing stop

Trailing stop duoc goi moi tick cho position cung symbol va magic. EA dung ATR raw cua nen da dong gan nhat `ATR[1]`.

Cong thuc khoang cach trailing:

```text
distance = ATR[1] x ATRFactor
activationDist = ATR[1] x TSLActivationATR
stepDist = ATR[1] x TSLStepATR
```

### TSL_CONTINUOUS

SL duoc keo lien tuc theo gia:

- Lenh BUY: `newSL = Bid - distance`.
- Lenh SELL: `newSL = Ask + distance`.

EA chi doi SL neu SL moi tot hon SL cu. BUY chi keo len, SELL chi keo xuong.

### TSL_BREAKEVEN_FIRST

EA chi bat dau trailing khi lenh da loi it nhat `TSLActivationATR x ATR`.

- BUY chi kich hoat khi `Bid - openPrice >= activationDist`.
- SELL chi kich hoat khi `openPrice - Ask >= activationDist`.

Sau khi kich hoat, SL van duoc dat theo cong thuc ATR trailing, khong phai bat buoc dat dung entry.

### TSL_STEP

Day la default trong `JINPA_v2.2`.

EA van tinh SL theo `Bid - distance` voi BUY va `Ask + distance` voi SELL, nhung chi modify khi SL moi di duoc toi thieu `TSLStepATR x ATR` so voi SL hien tai.

- BUY: chi doi neu `newSL >= currentSL + stepDist`.
- SELL: chi doi neu `newSL <= currentSL - stepDist`.

Muc nay giup giam viec sua SL lien tuc, hop voi market nhiu va broker gioi han tan suat modify.

### Bo loc chong spam lenh modify

Ngoai mode trailing, EA con co 2 lop loc:

- Chi modify neu SL thay doi it nhat `3 tick`.
- Cung mot ticket chi duoc modify toi da 1 lan moi `10 giay`.

EA cung dieu chinh SL theo stop level cua broker de tranh dat SL qua gan gia hien tai.

## 4. Bo input basic de chay an toan

Preset nay uu tien nhe lot, de hoc cach panel/trailing hoat dong, phu hop demo hoac live von nho. Can test tren symbol/broker cu the truoc khi dung tien that.

```text
BASIC SETTINGS
MagicNumber             = 1010
slPointsValue           = 0
POExpirationMinutes     = 360
MaxDrawdownDaily        = 3.0

RISK MANAGEMENT
MoneyManagement         = MM_EQUITY_RISK_PERCENT
RiskPercent             = 0.25
FixedVolume             = 0.01
MinLotPerEquitySteps    = 1000

MOVING AVERAGE
MAPeriod                = 21
MAMethod                = MODE_EMA
MAShift                 = 0
MAPrice                 = PRICE_CLOSE

ATR SETTINGS
ATRPeriod               = 14
ATRFactor               = 2.0
ATRFactorPO             = 1.5

TRAILING STOP
TSLMode                 = TSL_STEP
TSLActivationATR        = 1.0
TSLStepATR              = 0.8

LOGGING
LogLevel                = LOG_INFO
```

Neu muon don gian hon nua cho tai khoan rat nho, co the dung:

```text
MoneyManagement         = MM_FIXED_LOT_SIZE
FixedVolume             = 0.01
RiskPercent             = 0.25
MaxDrawdownDaily        = 2.0
TSLMode                 = TSL_STEP
ATRFactor               = 2.0
ATRFactorPO             = 1.5
TSLStepATR              = 1.0
```

## 5. Luu y van hanh

- EA chi quan ly lenh co cung `MagicNumber` va symbol hien tai.
- Nen doi `MagicNumber` neu chay nhieu chart/chien luoc rieng biet.
- Voi `SL = atr`, nen cho chart chay qua it nhat mot tick sau khi attach EA de ATR duoc nap.
- Khi market dong cua cuoi tuan, EA chi in warning cho FX/metal-like symbol; trader van can tu kiem tra dieu kien giao dich.
- `MaxDrawdownDaily` tinh theo equity cao nhat/thap nhat trong ngay theo server time. Gia tri tra ve la so am, vi du `-2.5%`.
