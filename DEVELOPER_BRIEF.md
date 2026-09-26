# MQL5 Expert Advisor Development Brief

## Project Overview
Create a production-ready MQL5 Expert Advisor that integrates AI-powered trading signals via REST API with zero compilation errors and zero warnings.

## Core Requirements

### 1. Trading Modes (3 Configurable Modes)
- **Scalping Mode**: Uses M1 (1-minute) timeframe, rapid entry/exit signals
- **Intraday Mode**: Uses M15 (15-minute) timeframe, medium-term trading
- **Swing Mode**: Uses H4 (4-hour) timeframe, longer-term positions

Mode selection via input parameter enum.

### 2. AI API Integration
- Accept API key via input parameter
- Send POST request to configurable AI endpoint (default: OpenAI-compatible)
- Include in request:
  - Last 30 candles (OHLCV data)
  - Current market price (bid/ask)
  - Trading symbol
  - Current mode and timeframe
- Parse JSON response containing:
  - `signal`: BUY, SELL, or HOLD (string)
  - `reason`: Trading rationale (string)
  - `confidence`: Signal strength 0-1 (double)

### 3. Position Management
- **Lot Size**: Adjustable input parameter (default 0.10)
- **Max Open Trades**: Adjustable input parameter limiting open positions per symbol (default 3)
- **Signal Cooldown**: Adjustable wait time between AI signal checks in seconds (default 60)
- Track open positions per symbol and prevent exceeding max trade limit

### 4. Order Execution
- BUY signal → market buy order with LotSize
- SELL signal → market sell order with LotSize
- HOLD signal → no action, wait for next signal
- Log all order results (success/failure) to Journal

### 5. Input Parameters
```
string   ApiKey = "YOUR_API_KEY_HERE"
string   ApiUrl = "https://api.openai.com/v1/chat/completions"
string   ModelName = "gpt-4o-mini"
double   LotSize = 0.10
int      MaxTrades = 3
int      SignalCooldownSeconds = 60
bool     AllowAutoTrading = true
enum     EA_Mode = MODE_SCALPING (OPTIONS: MODE_SCALPING, MODE_INTRADAY, MODE_SWING)
```

## Technical Specifications

### Compilation Requirements
- **Must compile with ZERO errors and ZERO warnings** using MetaTrader 5 MetaEditor
- Use only standard MQL5 library includes (Trade\Trade.mqh)
- Avoid function name conflicts with built-in MQL5 functions
- Do NOT override system functions like StringToUpper()

### API Request Format
Use OpenAI-compatible REST API format:
```json
{
  "model": "gpt-4o-mini",
  "messages": [
    {"role": "system", "content": "You are a trading analyst..."},
    {"role": "user", "content": "Market analysis prompt..."}
  ],
  "temperature": 0.2
}
```

### JSON Parsing
- Parse OpenAI response structure (nested content field)
- Extract inner JSON object from content field
- Safely handle escaped JSON characters
- Fallback to HOLD signal if JSON parsing fails

### Risk Management Notes
- This is a basic version (production version should add SL/TP)
- No position sizing beyond fixed lot size
- No drawdown limits
- Suitable for educational/testing purposes only

## Code Quality Standards
- Clean, readable code with comments
- Proper error handling for API failures
- Graceful handling of invalid API responses
- No memory leaks or buffer overflows
- Use descriptive function/variable names
- Modular function design

## Deliverables
1. `MQL5_EA_Production.mq5` - Main EA file (compiles cleanly)
2. `README.md` - Setup and usage instructions
3. `API_SETUP_GUIDE.md` - Step-by-step API configuration for different providers

## Testing Checklist
- [ ] Compiles with 0 errors, 0 warnings
- [ ] All input parameters work as expected
- [ ] Switches between 3 modes correctly
- [ ] Sends proper API requests with valid JSON
- [ ] Parses OpenAI responses correctly
- [ ] Places BUY/SELL/HOLD orders according to signals
- [ ] Respects MaxTrades limit
- [ ] Respects SignalCooldown interval
- [ ] Logs all decisions to Journal
- [ ] Handles API failures gracefully

## Notes
- Do NOT use deprecated MQL5 functions
- Ensure compatibility with MetaTrader 5 Build 3000+
- Use CTrade class from Trade.mqh for order management
- Handle all string operations carefully (escaping, unescaping)
- Avoid ambiguous function overloading

---

**Priority:** Production-ready, zero errors/warnings EA that integrates with AI APIs for algorithmic trading across three timeframe modes.
