#property strict
#property version   "1.00"
#property description "AI-based MQL5 Expert Advisor with Scalping, Intraday, and Swing modes"

#include <Trade\Trade.mqh>

input string   ApiKey = "YOUR_API_KEY_HERE";
input string   ApiUrl = "https://api.openai.com/v1/chat/completions";
input string   ModelName = "gpt-4o-mini";

input double   LotSize = 0.10;
input int      MaxTrades = 3;
input int      SignalCooldownSeconds = 60;
input bool     AllowTrading = true;

enum TradingMode
{
   MODE_SCALPING,
   MODE_INTRADAY,
   MODE_SWING
};

input TradingMode EA_Mode = MODE_SCALPING;

CTrade trade;
datetime lastSignalTime = 0;

int OnInit()
{
   trade.SetExpertMagicNumber(20260926);
   trade.SetDeviationInPoints(20);
   Print("AI EA Initialized. Mode: ", GetModeString(EA_Mode), " LotSize: ", LotSize, " MaxTrades: ", MaxTrades);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   Print("AI EA Deinitialized. Reason: ", reason);
}

void OnTick()
{
   if(!AllowTrading)
      return;

   datetime now = TimeCurrent();
   if(lastSignalTime != 0 && now - lastSignalTime < SignalCooldownSeconds)
      return;

   string signal = "";
   string reason = "";
   double confidence = 0.0;

   if(!GetAITradingSignal(signal, reason, confidence))
      return;

   if(NormalizeString(signal) == "HOLD")
   {
      lastSignalTime = now;
      Print("AI HOLD signal | reason: ", reason, " confidence: ", confidence);
      return;
   }

   if(CountOpenPositionsForSymbol(_Symbol) >= MaxTrades)
   {
      lastSignalTime = now;
      Print("Max trade count reached for ", _Symbol);
      return;
   }

   lastSignalTime = now;

   if(NormalizeString(signal) == "BUY")
   {
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      bool ok = trade.Buy(LotSize, _Symbol, ask, 0, 0);
      if(ok)
         Print("BUY order opened | reason: ", reason, " confidence: ", confidence);
      else
         Print("BUY failed: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
   }
   else if(NormalizeString(signal) == "SELL")
   {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      bool ok = trade.Sell(LotSize, _Symbol, bid, 0, 0);
      if(ok)
         Print("SELL order opened | reason: ", reason, " confidence: ", confidence);
      else
         Print("SELL failed: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
   }
}

bool GetAITradingSignal(string &signal, string &reason, double &confidence)
{
   if(ApiKey == "YOUR_API_KEY_HERE" || StringLen(ApiKey) < 10)
   {
      Print("Set a valid API key in the EA inputs before trading.");
      return false;
   }

   string requestBody = BuildRequestBody();
   string headers = "Content-Type: application/json\r\nAuthorization: Bearer " + ApiKey;

   uchar response[];
   string responseHeaders = "";
   
   int res = WebRequest("POST", ApiUrl, headers, NULL, requestBody, response, responseHeaders);

   if(res == -1)
   {
      Print("WebRequest failed. Error: ", GetLastError());
      return false;
   }

   if(ArraySize(response) == 0)
   {
      Print("Empty AI response.");
      return false;
   }

   string raw = CharArrayToString(response);
   Print("AI raw response: ", raw);

   string content = ExtractStringField(raw, "content");
   if(content == "")
   {
      Print("No content field found in AI response.");
      return false;
   }

   string cleaned = UnescapeJsonText(content);
   string payload = ExtractFirstJsonObject(cleaned);

   if(payload == "")
   {
      Print("Could not find JSON payload in AI response.");
      return false;
   }

   signal = NormalizeString(TrimWhitespace(ExtractJsonValue(payload, "signal")));
   reason = TrimWhitespace(ExtractJsonValue(payload, "reason"));
   
   string confStr = TrimWhitespace(ExtractJsonValue(payload, "confidence"));
   confidence = StringToDouble(confStr);

   if(signal != "BUY" && signal != "SELL" && signal != "HOLD")
   {
      signal = "HOLD";
      reason = "AI signal invalid";
      confidence = 0.0;
   }

   if(reason == "")
      reason = "AI trading recommendation";

   return true;
}

string BuildRequestBody()
{
   string prompt = BuildPrompt();
   string body = "{\n";
   body += "  \"model\": \"" + ModelName + "\",\n";
   body += "  \"messages\": [\n";
   body += "    {\"role\": \"system\", \"content\": \"You are a trading analyst. Return strict JSON only with fields: signal, reason, confidence. signal must be BUY, SELL, or HOLD. confidence must be a number from 0 to 1.\"},\n";
   body += "    {\"role\": \"user\", \"content\": \"" + EscapeJson(prompt) + "\"}\n";
   body += "  ],\n";
   body += "  \"temperature\": 0.2\n";
   body += "}\n";
   return body;
}

string BuildPrompt()
{
   ENUM_TIMEFRAMES tf = GetModeTimeframe(EA_Mode);
   MqlRates rates[];
   int copied = CopyRates(_Symbol, tf, 0, 30, rates);

   string prompt = "You are a professional algorithmic trader.\\n";
   prompt += "Symbol: " + _Symbol + "\\n";
   prompt += "Mode: " + GetModeString(EA_Mode) + "\\n";
   prompt += "Timeframe: " + GetTimeframeString(tf) + "\\n";
   prompt += "Return only valid JSON with keys: signal, reason, confidence.\\n";
   prompt += "Allowed signal values: BUY, SELL, HOLD.\\n";
   prompt += "confidence must be between 0 and 1.\\n";
   prompt += "Current bid = " + DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits) + ", ask = " + DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits) + "\\n";

   if(copied > 0)
   {
      prompt += "Recent candles:\\n";
      for(int i = 0; i < copied; i++)
      {
         prompt += "C" + IntegerToString(i) + ": O=" + DoubleToString(rates[i].open, _Digits) +
                   " H=" + DoubleToString(rates[i].high, _Digits) +
                   " L=" + DoubleToString(rates[i].low, _Digits) +
                   " C=" + DoubleToString(rates[i].close, _Digits) +
                   " V=" + IntegerToString((int)rates[i].tick_volume) + "\\n";
      }
   }

   prompt += "Do not return markdown or extra explanation. JSON only.";
   return prompt;
}

ENUM_TIMEFRAMES GetModeTimeframe(TradingMode mode)
{
   switch(mode)
   {
      case MODE_SCALPING: return PERIOD_M1;
      case MODE_INTRADAY: return PERIOD_M15;
      case MODE_SWING: return PERIOD_H4;
      default: return PERIOD_M5;
   }
}

string GetModeString(TradingMode mode)
{
   switch(mode)
   {
      case MODE_SCALPING: return "SCALPING";
      case MODE_INTRADAY: return "INTRADAY";
      case MODE_SWING: return "SWING";
      default: return "UNKNOWN";
   }
}

string GetTimeframeString(ENUM_TIMEFRAMES tf)
{
   switch(tf)
   {
      case PERIOD_M1: return "M1";
      case PERIOD_M5: return "M5";
      case PERIOD_M15: return "M15";
      case PERIOD_H1: return "H1";
      case PERIOD_H4: return "H4";
      case PERIOD_D1: return "D1";
      default: return "UNKNOWN";
   }
}

int CountOpenPositionsForSymbol(string sym)
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;

      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL) == sym)
            count++;
      }
   }
   return count;
}

string ExtractFirstJsonObject(string text)
{
   int start = StringFind(text, "{");
   if(start == -1)
      return "";

   int end = StringFind(text, "}", start);
   while(end != -1)
   {
      string candidate = StringSubstr(text, start, end - start + 1);
      if(StringFind(candidate, "\"signal\"") != -1)
         return candidate;

      start = end + 1;
      int nextBrace = StringFind(text, "{", start);
      if(nextBrace == -1)
         break;
      start = nextBrace;
      end = StringFind(text, "}", start);
   }

   return "";
}

string ExtractStringField(string json, string key)
{
   string pattern = "\"" + key + "\"";
   int pos = StringFind(json, pattern);
   if(pos == -1)
      return "";

   pos = StringFind(json, ":", pos + StringLen(pattern));
   if(pos == -1)
      return "";

   pos++;
   while(pos < StringLen(json) && (json[pos] == ' ' || json[pos] == '\t' || json[pos] == '\n' || json[pos] == '\r'))
      pos++;

   if(pos >= StringLen(json))
      return "";

   if(json[pos] == '"')
   {
      pos++;
      int end = pos;
      while(end < StringLen(json))
      {
         if(json[end] == '\\' && end + 1 < StringLen(json))
         {
            end += 2;
            continue;
         }
         if(json[end] == '"')
            break;
         end++;
      }

      return StringSubstr(json, pos, end - pos);
   }

   int end = pos;
   while(end < StringLen(json) && json[end] != ',' && json[end] != '}')
      end++;

   return StringSubstr(json, pos, end - pos);
}

string ExtractJsonValue(string json, string key)
{
   string value = ExtractStringField(json, key);
   return value;
}

string UnescapeJsonText(string text)
{
   text = StringReplace(text, "\\\"", "\"");
   text = StringReplace(text, "\\n", "\n");
   text = StringReplace(text, "\\r", "\r");
   text = StringReplace(text, "\\t", "\t");
   text = StringReplace(text, "\\\\", "\\");
   return text;
}

string EscapeJson(string text)
{
   text = StringReplace(text, "\\", "\\\\");
   text = StringReplace(text, "\"", "\\\"");
   text = StringReplace(text, "\n", "\\n");
   text = StringReplace(text, "\r", "\\r");
   return text;
}

string TrimWhitespace(string text)
{
   int start = 0;
   int end = StringLen(text) - 1;

   while(start <= end && (text[start] == ' ' || text[start] == '\n' || text[start] == '\r' || text[start] == '\t'))
      start++;

   while(end >= start && (text[end] == ' ' || text[end] == '\n' || text[end] == '\r' || text[end] == '\t'))
      end--;

   if(start > end)
      return "";

   return StringSubstr(text, start, end - start + 1);
}

string NormalizeString(string text)
{
   text = TrimWhitespace(text);
   
   string result = "";
   for(int i = 0; i < StringLen(text); i++)
   {
      int ch = StringGetCharacter(text, i);
      if(ch >= 97 && ch <= 122)
         ch -= 32;
      result += CharToString((uchar)ch);
   }
   
   return result;
}

string CharToString(uchar ch)
{
   uchar arr[2];
   arr[0] = ch;
   arr[1] = 0;
   return CharArrayToString(arr);
}

string StringReplace(string text, string find, string replace)
{
   int pos = 0;
   string result = text;
   while((pos = StringFind(result, find, pos)) != -1)
   {
      result = StringSubstr(result, 0, pos) + replace + StringSubstr(result, pos + StringLen(find));
      pos += StringLen(replace);
   }
   return result;
}

double StringToDouble(string text)
{
   text = TrimWhitespace(text);
   if(text == "")
      return 0.0;
   
   double result = 0.0;
   int sign = 1;
   int dotPos = -1;
   
   for(int i = 0; i < StringLen(text); i++)
   {
      int ch = StringGetCharacter(text, i);
      
      if(ch == '-')
         sign = -1;
      else if(ch == '.')
         dotPos = i;
      else if(ch >= 48 && ch <= 57)
      {
         result = result * 10.0 + (double)(ch - 48);
      }
   }
   
   if(dotPos != -1)
   {
      int decimalCount = StringLen(text) - dotPos - 1;
      double divisor = 1.0;
      for(int i = 0; i < decimalCount; i++)
         divisor *= 10.0;
      result = result / divisor;
   }
   
   return result * sign;
}
