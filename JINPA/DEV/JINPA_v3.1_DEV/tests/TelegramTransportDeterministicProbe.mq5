#property strict
#property version "1.00"
#property description "JINPA v3.1 DEV Phase 5C Telegram transport deterministic probe"

#include "../watch/notification/TelegramNotificationTransport.mqh"

int g_passed = 0;
int g_failed = 0;

void Check(const bool condition, const string name)
{
   if(condition)
   {
      g_passed++;
      Print("[TELEGRAM_TRANSPORT_TEST][PASS] ", name);
   }
   else
   {
      g_failed++;
      Print("[TELEGRAM_TRANSPORT_TEST][FAIL] ", name);
   }
}

void TestConfiguration(void)
{
   CTelegramNotificationTransport transport;
   transport.Configure(false, "", "");
   Check(transport.State() == JINPA_TELEGRAM_DISABLED
         && transport.StatusText() == "DISABLED",
         "CONFIG_01_DISABLED");

   transport.Configure(true, "", "chat-placeholder");
   Check(transport.State() == JINPA_TELEGRAM_NOT_CONFIGURED
         && transport.StatusText()
            == "NOT CONFIGURED | Bot Token missing",
         "CONFIG_02_MISSING_TOKEN");

   transport.Configure(true, "token-placeholder", "");
   Check(transport.State() == JINPA_TELEGRAM_NOT_CONFIGURED
         && transport.StatusText() == "NOT CONFIGURED | Chat ID missing",
         "CONFIG_03_MISSING_CHAT_ID");

   transport.Configure(true, "token-placeholder", "chat-placeholder");
   Check(transport.State() == JINPA_TELEGRAM_READY
         && transport.IsConfigured() && transport.StatusText() == "READY",
         "CONFIG_04_READY_TO_ATTEMPT");
}

void TestRequestFormatting(void)
{
   CTelegramNotificationTransport transport;
   transport.Configure(true, "token-placeholder", "+123&45");
   Check(transport.LabProbeEndpointShape(),
         "REQUEST_05_ENDPOINT_SHAPE_PRIVATE");

   const string body = transport.LabProbeBuildBody("A B\n&=+%");
   Check(StringFind(body, "chat_id=%2B123%2645") == 0,
         "REQUEST_06_CHAT_ID_FORM_ENCODED");
   Check(StringFind(body, "&text=A%20B%0A%26%3D%2B%25") > 0,
         "REQUEST_07_MESSAGE_FORM_ENCODED");

   const string encoded = transport.LabProbeUrlEncode(
      "A B\n&=+% café/?:#|");
   Check(encoded
         == "A%20B%0A%26%3D%2B%25%20caf%C3%A9%2F%3F%3A%23%7C",
         "ENCODING_08_UTF8_AND_RESERVED_CHARACTERS");
}

void TestSecurityAndResponseClassification(void)
{
   const string token = "token-placeholder";
   const string chat = "chat-placeholder";
   CTelegramNotificationTransport transport;
   transport.Configure(true, token, chat);
   const string readyDiagnostic = transport.StatusText();
   Check(StringFind(readyDiagnostic, token) < 0
         && StringFind(readyDiagnostic, chat) < 0
         && StringFind(readyDiagnostic, "https://") < 0,
         "SECURITY_09_DIAGNOSTIC_HAS_NO_SECRET_OR_URL");

   Check(transport.LabProbeClassifyResponse(
            200, 0, "{ \"ok\" : true, \"result\" : {} }")
         && transport.StatusText() == "SEND SUCCESS",
         "RESPONSE_10_HTTP_AND_API_SUCCESS");
   Check(!transport.LabProbeClassifyResponse(
            401, 0, "{\"ok\":false}")
         && transport.StatusText() == "SEND FAILED | HTTP=401",
         "RESPONSE_11_HTTP_FAILURE");
   Check(!transport.LabProbeClassifyResponse(
            200, 0, "{\"ok\":false,\"description\":\"bad\"}")
         && StringFind(transport.StatusText(), "API response not ok") >= 0,
         "RESPONSE_12_API_FAILURE");
   Check(!transport.LabProbeClassifyResponse(-1, 4014, "")
         && transport.StatusText() == "SEND FAILED | error=4014"
         && StringFind(transport.StatusText(), token) < 0
         && StringFind(transport.StatusText(), chat) < 0,
         "RESPONSE_13_WEBREQUEST_FAILURE_SANITIZED");
}

void TestTesterGuard(void)
{
   CTelegramNotificationTransport transport;
   transport.Configure(true, "token-placeholder", "chat-placeholder");
   const bool sent = transport.Send("deterministic tester message");
   Check((bool)MQLInfoInteger(MQL_TESTER) && !sent
         && transport.RealRequestAttempts() == 0
         && transport.StatusText() == "SUPPRESSED | Strategy Tester",
         "TESTER_14_NO_REAL_WEBREQUEST");
}

int OnInit(void)
{
   TestConfiguration();
   TestRequestFormatting();
   TestSecurityAndResponseClassification();
   TestTesterGuard();
   Print("[TELEGRAM_TRANSPORT_TEST][SUMMARY] passed=", g_passed,
         " failed=", g_failed,
         " trades=0 pending=0 cancels=0 closes=0 http_attempts=0");
   return g_failed == 0 ? INIT_SUCCEEDED : INIT_FAILED;
}

void OnTick(void) { ExpertRemove(); }
