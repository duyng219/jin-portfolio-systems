#ifndef JINPA_TELEGRAM_NOTIFICATION_TRANSPORT_MQH
#define JINPA_TELEGRAM_NOTIFICATION_TRANSPORT_MQH

enum ENUM_JINPA_TELEGRAM_STATE
{
   JINPA_TELEGRAM_DISABLED = 0,
   JINPA_TELEGRAM_NOT_CONFIGURED,
   JINPA_TELEGRAM_READY
};

// Telegram delivery only. Notification policy, formatting, FIFO and dedup
// remain owned by CStructureNotificationManager.
class CTelegramNotificationTransport
{
private:
   bool   m_enabled;
   string m_botToken;
   string m_chatId;
   int    m_timeoutMs;
   int    m_lastHttpCode;
   int    m_lastWebRequestError;
   int    m_realRequestAttempts;
   string m_lastDiagnostic;

   bool IsUnreserved(const uchar value) const
   {
      return (value >= 'A' && value <= 'Z')
             || (value >= 'a' && value <= 'z')
             || (value >= '0' && value <= '9')
             || value == '-' || value == '_' || value == '.' || value == '~';
   }

   string HexByte(const uchar value) const
   {
      const string digits = "0123456789ABCDEF";
      return StringSubstr(digits, (int)value / 16, 1)
             + StringSubstr(digits, (int)value % 16, 1);
   }

   string UrlEncode(const string value) const
   {
      uchar bytes[];
      const int count = StringToCharArray(value, bytes, 0, WHOLE_ARRAY,
                                          CP_UTF8);
      string encoded = "";
      const int payloadCount = MathMax(0, count - 1);
      for(int index = 0; index < payloadCount; index++)
      {
         if(IsUnreserved(bytes[index]))
            encoded += CharToString(bytes[index]);
         else
            encoded += "%" + HexByte(bytes[index]);
      }
      return encoded;
   }

   string BuildBody(const string message) const
   {
      return "chat_id=" + UrlEncode(m_chatId)
             + "&text=" + UrlEncode(message);
   }

   string Endpoint(void) const
   {
      return "https://api.telegram.org/bot" + m_botToken + "/sendMessage";
   }

   string CompactJson(const string response) const
   {
      string compact = response;
      StringReplace(compact, " ", "");
      StringReplace(compact, "\t", "");
      StringReplace(compact, "\r", "");
      StringReplace(compact, "\n", "");
      return compact;
   }

   bool ClassifyResponse(const int webRequestResult,
                         const string response)
   {
      m_lastHttpCode = webRequestResult;
      if(webRequestResult < 0)
      {
         m_lastDiagnostic = "SEND FAILED | error="
                            + IntegerToString(m_lastWebRequestError);
         return false;
      }
      if(webRequestResult < 200 || webRequestResult >= 300)
      {
         m_lastDiagnostic = "SEND FAILED | HTTP="
                            + IntegerToString(webRequestResult);
         return false;
      }
      if(StringFind(CompactJson(response), "\"ok\":true") < 0)
      {
         m_lastDiagnostic = "SEND FAILED | HTTP="
                            + IntegerToString(webRequestResult)
                            + " | API response not ok";
         return false;
      }
      m_lastDiagnostic = "SEND SUCCESS";
      return true;
   }

public:
   CTelegramNotificationTransport(void)
   {
      m_timeoutMs = 3000;
      Configure(false, "", "");
   }

   void Configure(const bool enabled, const string botToken,
                  const string chatId)
   {
      m_enabled = enabled;
      m_botToken = botToken;
      m_chatId = chatId;
      m_lastHttpCode = 0;
      m_lastWebRequestError = 0;
      m_realRequestAttempts = 0;
      if(!m_enabled)
         m_lastDiagnostic = "DISABLED";
      else if(m_botToken == "")
         m_lastDiagnostic = "NOT CONFIGURED | Bot Token missing";
      else if(m_chatId == "")
         m_lastDiagnostic = "NOT CONFIGURED | Chat ID missing";
      else
         m_lastDiagnostic = "READY";
   }

   bool IsEnabled(void) const { return m_enabled; }
   bool IsConfigured(void) const
   {
      return m_enabled && m_botToken != "" && m_chatId != "";
   }
   ENUM_JINPA_TELEGRAM_STATE State(void) const
   {
      if(!m_enabled)
         return JINPA_TELEGRAM_DISABLED;
      return IsConfigured() ? JINPA_TELEGRAM_READY
                            : JINPA_TELEGRAM_NOT_CONFIGURED;
   }
   string StatusText(void) const { return m_lastDiagnostic; }
   int LastHttpCode(void) const { return m_lastHttpCode; }
   int LastWebRequestError(void) const { return m_lastWebRequestError; }
   int RealRequestAttempts(void) const { return m_realRequestAttempts; }

   bool Send(const string message)
   {
      if(!m_enabled)
      {
         m_lastDiagnostic = "DISABLED";
         return false;
      }
      if(m_botToken == "")
      {
         m_lastDiagnostic = "NOT CONFIGURED | Bot Token missing";
         return false;
      }
      if(m_chatId == "")
      {
         m_lastDiagnostic = "NOT CONFIGURED | Chat ID missing";
         return false;
      }
      if((bool)MQLInfoInteger(MQL_TESTER))
      {
         m_lastDiagnostic = "SUPPRESSED | Strategy Tester";
         return false;
      }

      const string body = BuildBody(message);
      char requestData[];
      int requestSize = StringToCharArray(body, requestData, 0, WHOLE_ARRAY,
                                          CP_UTF8);
      if(requestSize > 0)
         ArrayResize(requestData, requestSize - 1);
      char responseData[];
      string responseHeaders = "";
      const string headers =
         "Content-Type: application/x-www-form-urlencoded\r\n";

      ResetLastError();
      m_realRequestAttempts++;
      const int result = WebRequest("POST", Endpoint(), headers, m_timeoutMs,
                                    requestData, responseData,
                                    responseHeaders);
      m_lastWebRequestError = result < 0 ? GetLastError() : 0;
      const string response = CharArrayToString(responseData, 0, WHOLE_ARRAY,
                                                CP_UTF8);
      return ClassifyResponse(result, response);
   }

   // Deterministic probe seams. None exposes credentials or performs network.
   string LabProbeUrlEncode(const string value) const
   {
      return UrlEncode(value);
   }
   string LabProbeBuildBody(const string message) const
   {
      return BuildBody(message);
   }
   bool LabProbeEndpointShape(void) const
   {
      const string endpoint = Endpoint();
      return StringFind(endpoint, "https://api.telegram.org/bot") == 0
             && StringFind(endpoint, "/sendMessage")
                == StringLen(endpoint) - StringLen("/sendMessage");
   }
   bool LabProbeClassifyResponse(const int webRequestResult,
                                 const int webRequestError,
                                 const string response)
   {
      m_lastWebRequestError = webRequestError;
      return ClassifyResponse(webRequestResult, response);
   }
};

#endif
