#property link          "https://www.earnforex.com/metatrader-expert-advisors/Trailing-Stop-on-Profit/"
#property version       "1.00"
#property strict
#property copyright     "EarnForex.com - 2022"
#property description   "This Expert Advisor will start trailing the stop-loss after a given profit is reached."
#property description   " "
#property description   "WARNING: No warranty. This EA is offered \"as is\". Use at your own risk.\r\n"
#property icon          "\\Files\\EF-Icon-64x64px.ico"

#include <Trade/Trade.mqh>
#include <errordescription.mqh>
#include <MQLTA Utils.mqh>

enum ENUM_CONSIDER
{
    All = -1,                  // All orders
    Buy = POSITION_TYPE_BUY,   // Buy only
    Sell = POSITION_TYPE_SELL, // Sell only
};

input group "Expert advisor settings"
input int TrailingStop = 50;                       // Trailing Stop, points
input int Profit = 100;                            // Profit in points when TS should kick in.
input group "Orders filtering options"
input ENUM_CONSIDER OnlyType = All;                // Apply to
input bool UseMagic = false;                       // Filter by magic number
input int MagicNumber = 0;                         // Magic number (if above is true)
input bool UseComment = false;                     // Filter by comment
input string CommentFilter = "";                   // Comment (if above is true)
input bool EnableTrailingParam = false;            // Enable trailing stop
input group "Notification options"
input bool EnableNotify = false;                   // Enable motifications feature
input bool SendAlert = true;                       // Send alert notification
input bool SendApp = true;                         // Send notification to mobile
input bool SendEmail = true;                       // Send notification via email
input group "Graphical window"
input bool ShowPanel = true;                       // Show graphical panel
input string IndicatorName = "TSOP";               // Indicator name (to name the objects)
input int Xoff = 20;                               // Horizontal spacing for the control panel
input int Yoff = 20;                               // Vertical spacing for the control panel

int OrderOpRetry = 5; // Number of position modification attempts.
bool EnableTrailing = EnableTrailingParam;
CTrade *Trade;

void OnInit()
{
    EnableTrailing = EnableTrailingParam;
    if (ShowPanel) DrawPanel();
    Trade = new CTrade;
}

void OnDeinit(const int reason)
{
    CleanPanel();
    delete Trade;
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
    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {

        ulong ticket = PositionGetTicket(i);

        if (ticket <= 0)
        {
            int Error = GetLastError();
            string ErrorText = ErrorDescription(Error);
            Print("ERROR - Unable to select the position - ", Error);
            Print("ERROR - ", ErrorText);
            break;
        }

        // Trading disabled.
        if (SymbolInfoInteger(PositionGetString(POSITION_SYMBOL), SYMBOL_TRADE_MODE) == SYMBOL_TRADE_MODE_DISABLED) continue;
        
        // Filters.
        if (PositionGetString(POSITION_SYMBOL) != Symbol()) continue;
        if ((UseMagic) && (PositionGetInteger(POSITION_MAGIC) != MagicNumber)) continue;
        if ((UseComment) && (StringFind(PositionGetString(POSITION_COMMENT), CommentFilter) < 0)) continue;
        if ((OnlyType != All) && (PositionGetInteger(POSITION_TYPE) != OnlyType)) continue;

        // Normalize trailing stop value to the point value.
        double TSTP = TrailingStop * _Point;
        double P = Profit * _Point;

        double Bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
        double Ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
        double OpenPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        double StopLoss = PositionGetDouble(POSITION_SL);
        double TakeProfit = PositionGetDouble(POSITION_TP);

        if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
        {
            if (NormalizeDouble(Bid - OpenPrice, _Digits) > NormalizeDouble(P, _Digits))
            {
                if ((TSTP != 0) && (StopLoss < NormalizeDouble(Bid - TSTP, _Digits)))
                {
                    ModifyPosition(ticket, OpenPrice, NormalizeDouble(Bid - TSTP, _Digits), TakeProfit);
                }
            }
        }
        else if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
        {
            if ((TSTP != 0) && (NormalizeDouble(OpenPrice - Ask, _Digits) > TSTP))
            {
                if ((StopLoss > NormalizeDouble(Ask + TSTP, _Digits)) || (StopLoss == 0))
                {
                    ModifyPosition(ticket, OpenPrice, NormalizeDouble(Ask + TSTP, _Digits), TakeProfit);
                }
            }
        }
    }
}

void ModifyPosition(ulong Ticket, double OpenPrice, double SLPrice, double TPPrice)
{
    for (int i = 1; i <= OrderOpRetry; i++) // Several attempts to modify the position.
    {
        bool result = Trade.PositionModify(Ticket, SLPrice, TPPrice);
        if (result)
        {
            Print("TRADE - UPDATE SUCCESS - Order ", Ticket, " new stop-loss ", SLPrice);
            NotifyStopLossUpdate(Ticket, SLPrice);
            break;
        }
        else
        {
            int Error = GetLastError();
            string ErrorText = ErrorDescription(Error);
            Print("ERROR - UPDATE FAILED - error modifying order ", Ticket, " return error: ", Error, " Open=", OpenPrice,
                  " Old SL=", PositionGetDouble(POSITION_SL),
                  " New SL=", SLPrice, " Bid=", SymbolInfoDouble(Symbol(), SYMBOL_BID), " Ask=", SymbolInfoDouble(Symbol(), SYMBOL_ASK));
            Print("ERROR - ", ErrorText);
        }
    }
}

void NotifyStopLossUpdate(ulong Ticket, double SLPrice)
{
    if (!EnableNotify) return;
    if ((!SendAlert) && (!SendApp) && (!SendEmail)) return;
    string EmailSubject = IndicatorName + " " + Symbol() + " Notification";
    string EmailBody = AccountInfoString(ACCOUNT_COMPANY) + " - " + AccountInfoString(ACCOUNT_NAME) + " - " + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + "\r\n\r\n" + IndicatorName + " Notification for " + Symbol() + "\r\n\r\n";
    EmailBody += "Stop-loss for order " + IntegerToString(Ticket) + " moved to " + DoubleToString(SLPrice, _Digits);
    string AlertText = IndicatorName + " - Notification: ";
    AlertText += "Stop-loss for order " + IntegerToString(Ticket) + " moved to " + DoubleToString(SLPrice, _Digits);
    string AppText = AccountInfoString(ACCOUNT_COMPANY) + " - " + AccountInfoString(ACCOUNT_NAME) + " - " + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + " - " + IndicatorName + " - " + Symbol() + " - ";
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
    Print(IndicatorName + " - last notification sent on " + TimeToString(TimeCurrent()));
}

string PanelBase = IndicatorName + "-P-BAS";
string PanelLabel = IndicatorName + "-P-LAB";
string PanelEnableDisable = IndicatorName + "-P-ENADIS";

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
    ChartRedraw();
}

void CleanPanel()
{
    ObjectsDeleteAll(ChartID(), IndicatorName);
}

void ChangeTrailingEnabled()
{
    if (EnableTrailing == false)
    {
        if (MQLInfoInteger(MQL_TRADE_ALLOWED)) EnableTrailing = true;
        else
        {
            MessageBox("You need to first enable Autotrading in your MetaTrader options", "WARNING", MB_OK);
        }
    }
    else EnableTrailing = false;
    DrawPanel();
}
//+------------------------------------------------------------------+