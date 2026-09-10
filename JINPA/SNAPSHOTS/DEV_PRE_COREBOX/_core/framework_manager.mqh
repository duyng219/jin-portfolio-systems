//+------------------------------------------------------------------+
//|                                            framework_manager.mqh |
//|                                                            duyng |
//|                                      https://github.com/duyng219 |
//+------------------------------------------------------------------+
#property copyright "duyng"
#property link      "https://github.com/duyng219"
#property strict

// ===== MANAGERS =====
#include "managers/indicators_manager.mqh"
#include "managers/bar_manager.mqh"
#include "managers/risk_manager.mqh"
#include "managers/drawdown_manager.mqh"
#include "managers/position_manager.mqh"   // depends on position_helper

// ===== INFRASTRUCTURE =====
#include "infrastructure/ui_manager.mqh"
#include "infrastructure/info_display.mqh"
#include "infrastructure/order_executor.mqh" // depends on risk, position, ui, position_helper
