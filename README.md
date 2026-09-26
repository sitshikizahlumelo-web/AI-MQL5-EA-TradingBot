# AI MQL5 Trading EA (SPECTOR_V9)

MQL5 Expert Advisor with AI-powered trading signals via API integration.

## Features

- **3 Trading Modes:**
  - Scalping (M1 timeframe)
  - Intraday (M15 timeframe)
  - Swing Trading (H4 timeframe)

- **Adjustable Parameters:**
  - Lot Size
  - Maximum number of open trades
  - Signal cooldown interval
  - AI model and API endpoint

## Setup

1. Open MetaEditor in MetaTrader 5
2. Copy `SPECTOR_V9.mq5` content into a new EA file
3. Replace `ApiKey` with your actual API key
4. Configure `ApiUrl` and `ModelName` for your AI provider (default: OpenAI)
5. Compile the file (F7)
6. Attach to a chart in MetaTrader 5
7. Set your preferred mode, lot size, and max trades

## Inputs

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| ApiKey | string | YOUR_API_KEY_HERE | Your AI API authentication key |
| ApiUrl | string | https://api.openai.com/v1/chat/completions | AI endpoint URL |
| ModelName | string | gpt-4o-mini | Model to use for signals |
| LotSize | double | 0.10 | Trading lot size |
| MaxTrades | int | 3 | Max open positions per symbol |
| SignalCooldownSeconds | int | 60 | Wait time between signal checks |
| AllowTrading | bool | true | Enable/disable trading |
| EA_Mode | enum | MODE_SCALPING | Trading mode (SCALPING/INTRADAY/SWING) |

## How It Works

1. EA retrieves the last 30 candles for the configured timeframe
2. Sends market data + symbol info to AI via API
3. AI returns JSON with: `signal` (BUY/SELL/HOLD), `reason`, `confidence`
4. EA opens BUY/SELL trades or holds based on signal
5. Respects `MaxTrades` limit per symbol
6. Logs all decisions to the Journal

## Important Notes

- **Demo Account First:** Always test on a demo account before live trading
- **No Risk Management:** This basic version has no stop loss or take profit
- **Educational Only:** This is a learning project. Trading involves risk.
- **API Costs:** Using GPT-4 or other paid models will incur API charges

## Compilation

Should compile with 0 errors and 0 warnings. If you get errors:
- Ensure `#include <Trade\Trade.mqh>` is available
- Check your MQL5 installation
- Verify API key syntax

## Disclaimer

Trading and investing involve substantial risk of loss. Past performance does not guarantee future results. Use this EA at your own risk.
