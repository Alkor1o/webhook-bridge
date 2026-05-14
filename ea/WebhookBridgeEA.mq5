//+------------------------------------------------------------------+
//|  WebhookBridgeEA.mq5  —  ark10.es                               |
//|  Polling a la API cada 1s, ejecuta ordenes y reporta resultado   |
//+------------------------------------------------------------------+
#property copyright "ark10.es"
#property version   "1.0"
#property strict

#include <Trade\Trade.mqh>

input string InpToken    = "pon-tu-token-aqui";
input string InpBaseURL  = "https://ark10.es";
input int    InpPollMs   = 1000;

CTrade trade;
string g_last_error = "";

int OnInit()
{
    EventSetMillisecondTimer(InpPollMs);
    Print("[WB] EA iniciada. Token: ", InpToken, " | URL: ", InpBaseURL);
    Print("[WB] IMPORTANTE: Anade ", InpBaseURL, " en Herramientas > Opciones > Expert Advisors > URLs permitidas");
    return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
    EventKillTimer();
    Print("[WB] EA detenida");
}

void OnTimer()
{
    PollAndExecute();
}

void OnTick() { }

//--- Polling principal
void PollAndExecute()
{
    string url = InpBaseURL + "/orders/pending/" + InpToken;
    char   response[];
    char   post_data[];
    string resp_headers;
    string req_headers = "Content-Type: application/json\r\n";

    int code = WebRequest("GET", url, req_headers, InpPollMs, post_data, response, resp_headers);

    if (code == -1)
    {
        static datetime last_warn = 0;
        if (TimeCurrent() - last_warn > 30)
        {
            Print("[WB] Sin conexion. Anade la URL en Opciones > Expert Advisors");
            last_warn = TimeCurrent();
        }
        return;
    }

    if (code != 200)
    {
        Print("[WB] HTTP ", code, " al hacer polling");
        return;
    }

    string json = CharArrayToString(response, 0, -1, CP_UTF8);

    if (StringFind(json, "\"pending\":true") == -1)
        return;

    int    order_id = ParseInt(json, "\"order_id\":");
    string action   = ParseString(json, "\"action\":\"", "\"");
    string symbol   = ParseString(json, "\"symbol\":\"", "\"");
    double lot      = ParseDouble(json, "\"lot\":");
    double sl       = ParseDouble(json, "\"sl\":");
    double tp       = ParseDouble(json, "\"tp\":");
    string comment  = ParseString(json, "\"comment\":\"", "\"");

    if (order_id <= 0 || action == "" || symbol == "")
    {
        Print("[WB] Payload invalido: ", json);
        return;
    }

    Print("[WB] Orden recibida #", order_id, " | ", action, " ", symbol, " lot=", lot);

    bool   ok         = ExecuteOrder(action, symbol, lot, sl, tp, comment);
    string status_str = ok ? "executed" : "error";
    string result_str = ok
        ? "Ticket:" + IntegerToString(trade.ResultOrder())
        : "Error " + IntegerToString(GetLastError()) + " " + g_last_error;

    ReportResult(order_id, status_str, result_str);
    Print("[WB] Resultado #", order_id, ": ", status_str, " | ", result_str);
}

//--- Ejecucion de ordenes
bool ExecuteOrder(string action, string symbol, double lot, double sl, double tp, string comment)
{
    if (lot <= 0.0) lot = 0.01;

    g_last_error = "";

    if (action == "buy")
    {
        if (!trade.Buy(lot, symbol, 0, sl, tp, comment))
        {
            g_last_error = trade.ResultComment();
            return false;
        }
        return true;
    }

    if (action == "sell")
    {
        if (!trade.Sell(lot, symbol, 0, sl, tp, comment))
        {
            g_last_error = trade.ResultComment();
            return false;
        }
        return true;
    }

    if (action == "close")
        return CloseBySymbol(symbol);

    if (action == "modify")
        return ModifySL_TP(symbol, sl, tp);

    g_last_error = "Accion no reconocida: " + action;
    return false;
}

bool CloseBySymbol(string symbol)
{
    bool all_ok = true;
    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if (PositionSelectByTicket(ticket) && PositionGetString(POSITION_SYMBOL) == symbol)
        {
            if (!trade.PositionClose(ticket))
            {
                g_last_error = trade.ResultComment();
                all_ok = false;
            }
        }
    }
    return all_ok;
}

bool ModifySL_TP(string symbol, double sl, double tp)
{
    bool all_ok = true;
    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if (PositionSelectByTicket(ticket) && PositionGetString(POSITION_SYMBOL) == symbol)
        {
            if (!trade.PositionModify(ticket, sl, tp))
            {
                g_last_error = trade.ResultComment();
                all_ok = false;
            }
        }
    }
    return all_ok;
}

//--- Reportar resultado a la API
void ReportResult(int order_id, string status_val, string result_val)
{
    string url  = InpBaseURL + "/orders/result/" + InpToken;
    string body = "{\"order_id\":" + IntegerToString(order_id) +
                  ",\"status\":\"" + status_val + "\"" +
                  ",\"result\":\"" + EscapeJson(result_val) + "\"}";

    char   post_data[];
    char   response[];
    string resp_headers;
    string req_headers = "Content-Type: application/json\r\n";

    StringToCharArray(body, post_data, 0, StringLen(body), CP_UTF8);
    ArrayResize(post_data, ArraySize(post_data) - 1);

    WebRequest("POST", url, req_headers, InpPollMs, post_data, response, resp_headers);
}

//--- Helpers JSON minimos (sin dependencias externas)
int ParseInt(const string &json, const string key)
{
    int pos = StringFind(json, key);
    if (pos == -1) return 0;
    pos += StringLen(key);
    string val = "";
    for (int i = pos; i < StringLen(json); i++)
    {
        string ch = StringSubstr(json, i, 1);
        if (ch == "," || ch == "}" || ch == " " || ch == "\n") break;
        val += ch;
    }
    return (int)StringToInteger(val);
}

double ParseDouble(const string &json, const string key)
{
    int pos = StringFind(json, key);
    if (pos == -1) return 0.0;
    pos += StringLen(key);
    string val = "";
    for (int i = pos; i < StringLen(json); i++)
    {
        string ch = StringSubstr(json, i, 1);
        if (ch == "," || ch == "}" || ch == " " || ch == "\n") break;
        val += ch;
    }
    if (val == "null") return 0.0;
    return StringToDouble(val);
}

string ParseString(const string &json, const string open_key, const string close_delim)
{
    int pos = StringFind(json, open_key);
    if (pos == -1) return "";
    pos += StringLen(open_key);
    int end = StringFind(json, close_delim, pos);
    if (end == -1) return "";
    return StringSubstr(json, pos, end - pos);
}

string EscapeJson(const string &s)
{
    string r = s;
    StringReplace(r, "\\", "\\\\");
    StringReplace(r, "\"", "\\\"");
    return r;
}
