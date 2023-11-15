#property link          "https://www.earnforex.com/metatrader-expert-advisors/Trailing-Stop-on-Profit/"
#property version       "1.02"
#property strict
#property copyright     "EarnForex.com - 2023"
#property description   "This Expert Advisor will start trailing the stop-loss after a given profit is reached."
#property description   " "
#property description   "WARNING: No warranty. This EA is offered \"as is\". Use at your own risk.\r\n"
#property icon          "\\Files\\EF-Icon-64x64px.ico"

#include <stdlib.mqh>
#include <MQLTA Utils.mqh>

enum ENUM_CONSIDER
{
    All = -1,       // All orders
    Buy = OP_BUY,   // Buy only
    Sell = OP_SELL, // Sell only
};

input string Comment_1 = "====================";   // Expert Advisor Settings
input int TrailingStop = 50;                       // Trailing Stop, points
input int Profit = 100;                            // Profit in points when TS should kick in.
input string Comment_2 = "====================";   // Orders Filtering Options
input bool OnlyCurrentSymbol = true;               // Apply to current symbol only
input ENUM_CONSIDER OnlyType = All;                // Apply to
input bool UseMagic = false;                       // Filter by magic number
input int MagicNumber = 0;                         // Magic number (if above is true)
input bool UseComment = false;                     // Filter by comment
input string CommentFilter = "";                   // Comment (if above is true)
input bool EnableTrailingParam = false;            // Enable trailing stop
input string Comment_3 = "====================";   // Notification Options
input bool EnableNotify = false;                   // Enable motifications feature
input bool SendAlert = true;                       // Send alert notification
input bool SendApp = true;                         // Send notification to mobile
input bool SendEmail = true;                       // Send notification via email
input string Comment_3a = "====================";  // Graphical Window
input bool ShowPanel = true;                       // Show graphical panel
input string ExpertName = "TSOP";                  // Expert name (to name the objects)
input int Xoff = 20;                               // Horizontal spacing for the control panel
input int Yoff = 20;                               // Vertical spacing for the control panel

int OrderOpRetry = 5; // Number of order modification attempts.
bool EnableTrailing = EnableTrailingParam;

void OnInit()
{
    EnableTrailing = EnableTrailingParam;
    if (ShowPanel) DrawPanel();
}

void OnDeinit(const int reason)
{
    CleanPanel();
}

void OnTick()
{
    if (EnableTrailing) TrailingStop();
    if (ShowPanel) DrawPanel();
}

void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
    if (id == CHARTEVENT_OBJECT_CLICK)
    {
        if (sparam == PanelEnableDisable) // Click on the enable/disable button.
        {
            ChangeTrailingEnabled();
        }
    }
    if (id == CHARTEVENT_KEYDOWN)
    {
        if (lparam == 27) // Escape key.
        {
            if (MessageBox("Are you sure you want to close the EA?", "Terminate?", MB_YESNO) == IDYES)
            {
                ExpertRemove();
            }
        }
    }
}

void TrailingStop()
{
    for (int i = OrdersTotal() - 1; i >= 0; i--)
    {
        if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES) == false)
        {
            int Error = GetLastError();
            string ErrorText = ErrorDescription(Error);
            Print("ERROR - Unable to select the order - ", Error);
            Print("ERROR - ", ErrorText);
            break;
        }
        if ((OnlyCurrentSymbol) && (OrderSymbol() != Symbol())) continue;
        if ((UseMagic) && (OrderMagicNumber() != MagicNumber)) continue;
        if ((UseComment) && (StringFind(OrderComment(), CommentFilter) < 0)) continue;
        if ((OnlyType != All) && (OrderType() != OnlyType)) continue;

        int eDigits = (int)MarketInfo(OrderSymbol(), MODE_DIGITS);
        double point = MarketInfo(OrderSymbol(), MODE_POINT);
        double ask = SymbolInfoDouble(OrderSymbol(), SYMBOL_ASK);
        double bid = SymbolInfoDouble(OrderSymbol(), SYMBOL_BID);
        double TickSize = SymbolInfoDouble(OrderSymbol(), SYMBOL_TRADE_TICK_SIZE);
        
        // Normalize trailing stop value to the point value.
        double TSTP = TrailingStop * point;
        double P = Profit * point;

        if (OrderType() == OP_BUY)
        {
            if (NormalizeDouble(bid - OrderOpenPrice(), eDigits) >= NormalizeDouble(P, eDigits))
            {
                double new_sl = NormalizeDouble(bid - TSTP, eDigits);
                if (TickSize > 0) // Adjust for tick size granularity.
                {
                    new_sl = NormalizeDouble(MathRound(new_sl / TickSize) * TickSize, eDigits);
                }
                if ((TSTP != 0) && (OrderStopLoss() < new_sl))
                {
                    ModifyOrder(OrderTicket(), OrderOpenPrice(), new_sl, OrderTakeProfit(), OrderSymbol());
                }
            }
        }
        else if (OrderType() == OP_SELL)
        {
            if (NormalizeDouble(OrderOpenPrice() - ask, eDigits) >= NormalizeDouble(P, eDigits))
            {
                double new_sl = NormalizeDouble(ask + TSTP, eDigits);
                if (TickSize > 0) // Adjust for tick size granularity.
                {
                    new_sl = NormalizeDouble(MathRound(new_sl / TickSize) * TickSize, eDigits);
                }
                if ((TSTP != 0) && ((OrderStopLoss() > new_sl) || (OrderStopLoss() == 0)))
                {
                    ModifyOrder(OrderTicket(), OrderOpenPrice(), new_sl, OrderTakeProfit(), OrderSymbol());
                }
            }
        }
    }
}

void ModifyOrder(int Ticket, double OpenPrice, double SLPrice, double TPPrice, string symbol)
{
    for (int i = 1; i <= OrderOpRetry; i++) // Several attempts to modify the order.
    {
        bool result = OrderModify(Ticket, OpenPrice, SLPrice, TPPrice, 0);
        if (result)
        {
            Print("TRADE - UPDATE SUCCESS - Order ", Ticket, " new stop-loss ", SLPrice);
            NotifyStopLossUpdate(Ticket, SLPrice, symbol);
            break;
        }
        else
        {
            int Error = GetLastError();
            string ErrorText = ErrorDescription(Error);
            Print("ERROR - UPDATE FAILED - error modifying order ", Ticket, " return error: ", Error, " Open=", OpenPrice,
                  " Old SL=", OrderStopLoss(),
                  " New SL=", SLPrice, " Bid=", MarketInfo(symbol, MODE_BID), " Ask=", MarketInfo(symbol, MODE_ASK));
            Print("ERROR - ", ErrorText);
        }
    }
}

void NotifyStopLossUpdate(int Ticket, double SLPrice, string symbol)
{
    if (!EnableNotify) return;
    if ((!SendAlert) && (!SendApp) && (!SendEmail)) return;
    string EmailSubject = ExpertName + " " + symbol + " Notification";
    string EmailBody = AccountCompany() + " - " + AccountName() + " - " + IntegerToString(AccountNumber()) + "\r\n\r\n" + ExpertName + " Notification for " + symbol + "\r\n\r\n";
    EmailBody += "Stop-loss for order " + IntegerToString(Ticket) + " moved to " + DoubleToString(SLPrice, _Digits);
    string AlertText = ExpertName + " - " + Symbol() + " Notification: ";
    AlertText += "Stop-loss for order " + IntegerToString(Ticket) + " moved to " + DoubleToString(SLPrice, _Digits);
    string AppText = AccountCompany() + " - " + AccountName() + " - " + IntegerToString(AccountNumber()) + " - " + ExpertName + " - " + symbol + " - ";
    AppText += "Stop-loss for order " + IntegerToString(Ticket) + " moved to " + DoubleToString(SLPrice, _Digits);
    if (SendAlert) Alert(AlertText);
    if (SendEmail)
    {
        if (!SendMail(EmailSubject, EmailBody)) Print("Error sending email " + IntegerToString(GetLastError()));
    }
    if (SendApp)
    {
        if (!SendNotification(AppText)) Print("Error sending notification " + IntegerToString(GetLastError()));
    }
    Print(ExpertName + " - last notification sent on " + TimeToString(TimeCurrent()));
}

string PanelBase = ExpertName + "-P-BAS";
string PanelLabel = ExpertName + "-P-LAB";
string PanelEnableDisable = ExpertName + "-P-ENADIS";

int PanelMovX = 50;
int PanelMovY = 20;
int PanelLabX = 150;
int PanelLabY = PanelMovY;
int PanelRecX = PanelLabX + 4;

void DrawPanel()
{
    string PanelText = "TSL on Profit";
    string PanelToolTip = "Trailing Stop on Profit by EarnForex";
    int Rows = 1;
    ObjectCreate(ChartID(), PanelBase, OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(ChartID(), PanelBase, OBJPROP_XDISTANCE, Xoff);
    ObjectSetInteger(ChartID(), PanelBase, OBJPROP_YDISTANCE, Yoff);
    ObjectSetInteger(ChartID(), PanelBase, OBJPROP_XSIZE, PanelRecX);
    ObjectSetInteger(ChartID(), PanelBase, OBJPROP_YSIZE, (PanelMovY + 2) * 1 + 2);
    ObjectSetInteger(ChartID(), PanelBase, OBJPROP_BGCOLOR, clrWhite);
    ObjectSetInteger(ChartID(), PanelBase, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(ChartID(), PanelBase, OBJPROP_STATE, false);
    ObjectSetInteger(ChartID(), PanelBase, OBJPROP_HIDDEN, true);
    ObjectSetInteger(ChartID(), PanelBase, OBJPROP_FONTSIZE, 8);
    ObjectSetInteger(ChartID(), PanelBase, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(ChartID(), PanelBase, OBJPROP_COLOR, clrBlack);

    DrawEdit(PanelLabel,
             Xoff + 2,
             Yoff + 2,
             PanelLabX,
             PanelLabY,
             true,
             10,
             PanelToolTip,
             ALIGN_CENTER,
             "Consolas",
             PanelText,
             false,
             clrNavy,
             clrKhaki,
             clrBlack);

    string EnableDisabledText = "";
    color EnableDisabledColor = clrNavy;
    color EnableDisabledBack = clrKhaki;
    if (EnableTrailing)
    {
        EnableDisabledText = "TRAILING ENABLED";
        EnableDisabledColor = clrWhite;
        EnableDisabledBack = clrDarkGreen;
    }
    else
    {
        EnableDisabledText = "TRAILING DISABLED";
        EnableDisabledColor = clrWhite;
        EnableDisabledBack = clrDarkRed;
    }

    DrawEdit(PanelEnableDisable,
             Xoff + 2,
             Yoff + (PanelMovY + 1)*Rows + 2,
             PanelLabX,
             PanelLabY,
             true,
             8,
             "Click to enable or disable the trailing stop feature",
             ALIGN_CENTER,
             "Consolas",
             EnableDisabledText,
             false,
             EnableDisabledColor,
             EnableDisabledBack,
             clrBlack);

    Rows++;

    ObjectSetInteger(ChartID(), PanelBase, OBJPROP_XSIZE, PanelRecX);
    ObjectSetInteger(ChartID(), PanelBase, OBJPROP_YSIZE, (PanelMovY + 1)*Rows + 3);
}

void CleanPanel()
{
    ObjectsDeleteAll(ChartID(), ExpertName);
}

void ChangeTrailingEnabled()
{
    if (EnableTrailing == false)
    {
        if (IsTradeAllowed()) EnableTrailing = true;
        else
        {
            MessageBox("You need to first enable Autotrading in your MetaTrader options", "WARNING", MB_OK);
        }
    }
    else EnableTrailing = false;
    DrawPanel();
}
//+------------------------------------------------------------------+