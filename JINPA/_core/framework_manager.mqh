//+------------------------------------------------------------------+
//|                                                         framework_manager.mqh |
//|                                                                                        duyng |
//|                                                   https://github.com/duyng219 |
//+------------------------------------------------------------------+
#property copyright "duyng"
#property link      "https://github.com/duyng219"

// ===== MANAGERS: Xử lý logic chính của hệ thống =====

// Quản lý indicator: tính toán signal mua/bán từ MACD, MA, SAR, MAMA...
#include "managers/indicators_manager.mqh"

// Thực thi giao dịch: mở/đóng order dựa vào signal
#include "managers/trade_executor.mqh"

// Quản lý vị thế: theo dõi các position mở, P&L, chi tiết order
#include "managers/position_manager.mqh"

// Quản lý thời gian: kiểm tra giờ giao dịch, market open/close
#include "managers/time_manager.mqh"

// Quản lý bar/candle: cập nhật dữ liệu OHLCV, phát hiện bar mới
#include "managers/bar_manager.mqh"

// Quản lý rủi ro: tính lot size, stop loss, take profit từ risk%
#include "managers/risk_manager.mqh"

// Quản lý drawdown: theo dõi mục vốn giảm, dừng giao dịch khi vượt ngưỡng
#include "managers/drawdown_manager.mqh"

// ===== INFRASTRUCTURE: Hệ thống hỗ trợ =====

// Vẽ UI: hiển thị button, panel, thông tin trên chart
#include "infrastructure/ui_manager.mqh"

// Hỗ trợ position: tính P&L, format dữ liệu position
#include "infrastructure/position_helper.mqh"

// Thực thi order: gửi buy/sell request tới MT5, xử lý lỗi
#include "infrastructure/order_executor.mqh"

// Hiển thị thông tin: log debug, statistics, trade info
#include "infrastructure/info_display.mqh"
