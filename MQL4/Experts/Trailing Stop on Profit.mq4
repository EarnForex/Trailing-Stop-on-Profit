#property link          "https://www.earnforex.com/metatrader-expert-advisors/Trailing-Stop-on-Profit/"
#property version       "1.04"
#property strict
#property copyright     "EarnForex.com - 2023-2026"
#property description   "This expert advisor will start trailing the stop-loss after a given profit is reached."
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

input string Comment_1 = "====================";    // Expert Advisor Settings
input int TrailingStop = 50;                        // Trailing Stop, points
input int Profit = 100;                             // Profit in points when TS should kick in
input bool DisableTPonTSL = false;                  // Disable take-profit when TS kicks in?
input string Comment_2 = "====================";    // Orders Filtering Options
input bool OnlyCurrentSymbol = true;                // Apply to current symbol only
input ENUM_CONSIDER OnlyType = All;                 // Apply to
input bool UseMagic = false;                        // Filter by magic number
input int MagicNumber = 0;                          // Magic number (if above is true)
input bool UseComment = false;                      // Filter by comment
input string CommentFilter = "";                    // Comment (if above is true)
input bool EnableTrailingParam = false;             // Enable trailing stop
input string Comment_3 = "====================";    // Notification Options
input bool EnableNotify = false;                    // Enable notifications feature
input bool SendAlert = true;                        // Send alert notification
input bool SendApp = false;                         // Send notification to mobile
input bool SendEmail = false;                       // Send notification via email
input string Comment_3a = "====================";   // Graphical Window
input bool ShowPanel = true;                        // Show graphical panel
input string ExpertName = "TSOP";                   // Expert name (to name the objects)
input int Xoff = 20;                                // Horizontal spacing for the control panel
input int Yoff = 20;                                // Vertical spacing for the control panel
input ENUM_BASE_CORNER ChartCorner = CORNER_LEFT_UPPER; // Chart Corner
input int FontSize = 10;                            // Font Size
input string Comment_4 = "====================";    // Potential TSL Lines
input bool ShowPotentialSLLines = false;            // Show potential TSL lines
input color PotentialSLBuyColor = clrDodgerBlue;    // Potential Buy TSL line color
input color PotentialSLSellColor = clrOrangeRed;    // Potential Sell TSL line color
input ENUM_LINE_STYLE PotentialSLStyle = STYLE_DOT; // Potential TSL line style
input int PotentialSLWidth = 1;                     // Potential TSL line width
input int PotentialSLLabelFontSize = 8;             // Potential TSL label font size
input string Comment_5 = "====================";    // Activation Lines
input bool ShowActivationLines = false;             // Show activation lines
input color ActivationBuyColor = clrDarkGray;       // Activation Buy line color
input color ActivationSellColor = clrDarkSlateGray; // Activation Sell line color
input ENUM_LINE_STYLE ActivationStyle = STYLE_DASH; // Activation line style
input int ActivationWidth = 1;                      // Activation line width
input int ActivationFontSize = 8;                   // Activation label font size

int OrderOpRetry = 5; // Number of order modification attempts.
double DPIScale; // Scaling parameter for the panel based on the screen DPI.
int PanelMovY, PanelLabX, PanelLabY, PanelRecX;
bool EnableTrailing = EnableTrailingParam;

void OnInit()
{
    if (TrailingStop <= 0)
    {
        Alert("Trailing Stop should be > 0.");
    }
    
    EnableTrailing = EnableTrailingParam;

    DPIScale = (double)TerminalInfoInteger(TERMINAL_SCREEN_DPI) / 96.0;

    PanelMovY = (int)MathRound(20 * DPIScale);
    PanelLabX = (int)MathRound(150 * DPIScale);
    PanelLabY = PanelMovY;
    PanelRecX = PanelLabX + 4;

    if (ShowPanel) DrawPanel();
    if (ShowPotentialSLLines || ShowActivationLines) EventSetTimer(1); // If lines are required, use timer to refresh the lines for off-market hours.
}

void OnDeinit(const int reason)
{
    CleanPanel();
    CleanPotentialSLLines();
    CleanActivationLines();
}

void OnTick()
{
    if (EnableTrailing) DoTrailingStop();
    DrawPotentialSLLines();
    DrawActivationLines();
}

void OnTimer()
{
    DrawPotentialSLLines();
    DrawActivationLines();
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
    else if (id == CHARTEVENT_KEYDOWN)
    {
        if (lparam == 27) // Escape key.
        {
            if (MessageBox("Are you sure you want to close the EA?", "Terminate?", MB_YESNO) == IDYES)
            {
                ExpertRemove();
            }
        }
    }
    else if (id == CHARTEVENT_CHART_CHANGE)
    {
        RepositionLabels();
    }
}

void DoTrailingStop()
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
        if (OnlyCurrentSymbol && OrderSymbol() != Symbol()) continue;
        if (UseMagic && OrderMagicNumber() != MagicNumber) continue;
        if (UseComment && StringFind(OrderComment(), CommentFilter) < 0) continue;
        if (OnlyType != All && OrderType() != OnlyType) continue;

        int eDigits = (int)SymbolInfoInteger(OrderSymbol(), SYMBOL_DIGITS);
        double point = SymbolInfoDouble(OrderSymbol(), SYMBOL_POINT);
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
                if (TSTP != 0 && OrderStopLoss() < new_sl)
                {
                    double new_tp = OrderTakeProfit();
                    if (DisableTPonTSL) new_tp = 0;
                    ModifyOrder(OrderTicket(), OrderOpenPrice(), new_sl, new_tp, OrderSymbol());
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
                if ((TSTP != 0 && OrderStopLoss() > new_sl) || OrderStopLoss() == 0)
                {
                    double new_tp = OrderTakeProfit();
                    if (DisableTPonTSL) new_tp = 0;
                    ModifyOrder(OrderTicket(), OrderOpenPrice(), new_sl, new_tp, OrderSymbol());
                }
            }
        }
    }
}

void ModifyOrder(int Ticket, double OpenPrice, double SLPrice, double TPPrice, string symbol)
{
    string TP_text = "";
    if (DisableTPonTSL && OrderTakeProfit() > 0) TP_text = ". TP set to zero.";
    for (int i = 1; i <= OrderOpRetry; i++) // Several attempts to modify the order.
    {
        bool result = OrderModify(Ticket, OpenPrice, SLPrice, TPPrice, 0);
        if (result)
        {
            Print("TRADE - UPDATE SUCCESS - Order ", Ticket, " new stop-loss ", SLPrice, TP_text);
            NotifyStopLossUpdate(Ticket, SLPrice, symbol, TP_text);
            break;
        }
        else
        {
            int Error = GetLastError();
            string ErrorText = ErrorDescription(Error);
            Print("ERROR - UPDATE FAILED - error modifying order ", Ticket, " return error: ", Error, " Open=", OpenPrice,
                  " Old SL=", OrderStopLoss(),
                  " New SL=", SLPrice, " Bid=", SymbolInfoDouble(symbol, SYMBOL_BID), " Ask=", SymbolInfoDouble(symbol, SYMBOL_ASK));
            Print("ERROR - ", ErrorText);
        }
    }
}

void NotifyStopLossUpdate(int Ticket, double SLPrice, string symbol, string TP_text)
{
    if (!EnableNotify) return;
    if (!SendAlert && !SendApp && !SendEmail) return;
    int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    string EmailSubject = ExpertName + " " + symbol + " Notification";
    string EmailBody = AccountCompany() + " - " + AccountName() + " - " + IntegerToString(AccountNumber()) + "\r\n\r\n" + ExpertName + " Notification for " + symbol + "\r\n\r\n";
    EmailBody += "Stop-loss for order " + IntegerToString(Ticket) + " moved to " + DoubleToString(SLPrice, digits) + TP_text;
    string AlertText = ExpertName + " - " + Symbol() + " Notification: ";
    AlertText += "Stop-loss for order " + IntegerToString(Ticket) + " moved to " + DoubleToString(SLPrice, digits) + TP_text;
    string AppText = AccountCompany() + " - " + AccountName() + " - " + IntegerToString(AccountNumber()) + " - " + ExpertName + " - " + symbol + " - ";
    AppText += "Stop-loss for order " + IntegerToString(Ticket) + " moved to " + DoubleToString(SLPrice, digits) + TP_text;
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
string PotentialSLLinePrefix = ExpertName + "-SL-";
string PotentialSLLabelPrefix = ExpertName + "-SLL-";
string ActivationLinePrefix = ExpertName + "-ACT-";
string ActivationLabelPrefix = ExpertName + "-ACTL-";

void DrawPanel()
{
    int SignX = 1;
    int YAdjustment = 0;
    if ((ChartCorner == CORNER_RIGHT_UPPER) || (ChartCorner == CORNER_RIGHT_LOWER))
    {
        SignX = -1; // Correction for right-side panel position.
    }
    if ((ChartCorner == CORNER_RIGHT_LOWER) || (ChartCorner == CORNER_LEFT_LOWER))
    {
        YAdjustment = (PanelMovY + 2) * 2 + 1 - PanelLabY; // Correction for upper side panel position.
    }

    string PanelText = "TSL on Profit";
    string PanelToolTip = "Trailing Stop on Profit by EarnForex";
    int Rows = 1;
    ObjectCreate(ChartID(), PanelBase, OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(ChartID(), PanelBase, OBJPROP_CORNER, ChartCorner);
    ObjectSetInteger(ChartID(), PanelBase, OBJPROP_XDISTANCE, Xoff);
    ObjectSetInteger(ChartID(), PanelBase, OBJPROP_YDISTANCE, Yoff + YAdjustment);
    ObjectSetInteger(ChartID(), PanelBase, OBJPROP_XSIZE, PanelRecX);
    ObjectSetInteger(ChartID(), PanelBase, OBJPROP_YSIZE, (PanelMovY + 1) * (Rows + 1) + 3);
    ObjectSetInteger(ChartID(), PanelBase, OBJPROP_BGCOLOR, clrWhite);
    ObjectSetInteger(ChartID(), PanelBase, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(ChartID(), PanelBase, OBJPROP_STATE, false);
    ObjectSetInteger(ChartID(), PanelBase, OBJPROP_HIDDEN, true);
    ObjectSetInteger(ChartID(), PanelBase, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(ChartID(), PanelBase, OBJPROP_COLOR, clrBlack);

    DrawEdit(PanelLabel,
             Xoff + 2 * SignX,
             Yoff + 2,
             PanelLabX,
             PanelLabY,
             true,
             FontSize,
             PanelToolTip,
             ALIGN_CENTER,
             "Consolas",
             PanelText,
             false,
             clrNavy,
             clrKhaki,
             clrBlack);
    ObjectSetInteger(ChartID(), PanelLabel, OBJPROP_CORNER, ChartCorner);

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
             Xoff + 2 * SignX,
             Yoff + (PanelMovY + 1) * Rows + 2,
             PanelLabX,
             PanelLabY,
             true,
             FontSize,
             "Click to enable or disable the trailing stop feature",
             ALIGN_CENTER,
             "Consolas",
             EnableDisabledText,
             false,
             EnableDisabledColor,
             EnableDisabledBack,
             clrBlack);
    ObjectSetInteger(ChartID(), PanelEnableDisable, OBJPROP_CORNER, ChartCorner);
}

void CleanPanel()
{
    ObjectsDeleteAll(ChartID(), ExpertName);
}

void ChangeTrailingEnabled()
{
    if (EnableTrailing == false)
    {
        if (!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
        {
            MessageBox("Automated trading is disabled in the platform's options! Please enable it via Tools->Options->Expert Advisors.", "WARNING", MB_OK);
            return;
        }
        if (!MQLInfoInteger(MQL_TRADE_ALLOWED))
        {
            MessageBox("Live Trading is disabled in the expert advisors's settings! Please tick the Allow Live Trading checkbox on the Common tab.", "WARNING", MB_OK);
            return;
        }
        EnableTrailing = true;
    }
    else EnableTrailing = false;
    DrawPanel();
    DrawActivationLines();
}

void DrawPotentialSLLines()
{
    if (!ShowPotentialSLLines)
    {
        CleanPotentialSLLines();
        return;
    }

    datetime leftTime = GetLeftVisibleBarTime();

    // Collect tickets that should currently have a potential TSL line.
    ulong activeTickets[];
    int activeCount = 0;

    for (int i = 0; i < OrdersTotal(); i++)
    {
        if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES) == false)
        {
            int Error = GetLastError();
            string ErrorText = ErrorDescription(Error);
            Print("ERROR - Unable to select the order - ", Error);
            Print("ERROR - ", ErrorText);
            continue;
        }
        int ticket = OrderTicket();
        if (OnlyCurrentSymbol && OrderSymbol() != Symbol()) continue;
        if (UseMagic && OrderMagicNumber() != MagicNumber) continue;
        if (UseComment && StringFind(OrderComment(), CommentFilter) < 0) continue;
        if (OnlyType != All && OrderType() != OnlyType) continue;

        string Instrument = OrderSymbol();
        double openPrice = OrderOpenPrice();
        int eDigits = (int)SymbolInfoInteger(Instrument, SYMBOL_DIGITS);
        double point = SymbolInfoDouble(Instrument, SYMBOL_POINT);

        // Initial TSL = OpenPrice +/- (Profit - TrailingStop) * point.
        // Rationale: trailing activates after price moves Profit*point in favour;
        // at that instant the EA places SL TrailingStop*point on the safe side,
        // so the level depends only on OpenPrice and the EA inputs (i.e. fixed).
        double slDist = (Profit - TrailingStop) * point;

        double slLevel = 0;
        color lineColor = clrNONE;
        string dirLabel = "";
        if (OrderType() == OP_BUY)
        {
            slLevel = NormalizeDouble(openPrice + slDist, eDigits);
            // Skip if the position's SL has already been moved to (or beyond) the Initial TSL.
            // OrderStopLoss() == 0 (no SL set) naturally fails this check, so the line is kept.
            if (OrderStopLoss() >= slLevel) continue;
            lineColor = PotentialSLBuyColor;
            dirLabel = "Buy";
        }
        else if (OrderType() == OP_SELL)
        {
            slLevel = NormalizeDouble(openPrice - slDist, eDigits);
            // For sells, "beyond" means a lower SL. Exclude OrderStopLoss() == 0 (no SL set).
            if (OrderStopLoss() > 0 && OrderStopLoss() <= slLevel) continue;
            lineColor = PotentialSLSellColor;
            dirLabel = "Sell";
        }
        else continue; // Pending orders: no potential TSL line.

        string lineName = PotentialSLLinePrefix + IntegerToString(ticket);
        string tooltip = "Initial TSL #" + IntegerToString(ticket) + " " + dirLabel + ": " + DoubleToString(slLevel, eDigits);
        CreateOrMoveHLine(lineName, slLevel, lineColor, PotentialSLStyle, PotentialSLWidth, tooltip);

        string labelName = PotentialSLLabelPrefix + IntegerToString(ticket);
        string labelText = "#" + IntegerToString(ticket) + " " + dirLabel + " Initial TSL";
        CreateOrMoveLabel(labelName, leftTime, slLevel, labelText, lineColor, PotentialSLLabelFontSize);

        ArrayResize(activeTickets, activeCount + 1);
        activeTickets[activeCount] = ticket;
        activeCount++;
    }

    // Remove potential TSL lines + labels for orders that no longer exist or are now filtered out.
    int totalObjects = ObjectsTotal(0, 0, OBJ_HLINE);
    for (int i = totalObjects - 1; i >= 0; i--)
    {
        string objName = ObjectName(0, i, 0, OBJ_HLINE);
        if (StringFind(objName, PotentialSLLinePrefix) != 0) continue;
        string ticketStr = StringSubstr(objName, StringLen(PotentialSLLinePrefix));
        ulong objTicket = (ulong)StringToInteger(ticketStr);
        bool found = false;
        for (int j = 0; j < activeCount; j++)
        {
            if (activeTickets[j] == objTicket)
            {
                found = true;
                break;
            }
        }
        if (!found)
        {
            ObjectDelete(0, objName);
            ObjectDelete(0, PotentialSLLabelPrefix + ticketStr);
        }
    }
    // Also clean orphaned labels (line was already removed).
    int totalText = ObjectsTotal(0, 0, OBJ_TEXT);
    for (int i = totalText - 1; i >= 0; i--)
    {
        string objName = ObjectName(0, i, 0, OBJ_TEXT);
        if (StringFind(objName, PotentialSLLabelPrefix) != 0) continue;
        string ticketStr = StringSubstr(objName, StringLen(PotentialSLLabelPrefix));
        ulong objTicket = (ulong)StringToInteger(ticketStr);
        bool found = false;
        for (int j = 0; j < activeCount; j++)
        {
            if (activeTickets[j] == objTicket)
            {
                found = true;
                break;
            }
        }
        if (!found) ObjectDelete(0, objName);
    }
}

void CleanPotentialSLLines()
{
    ObjectsDeleteAll(0, PotentialSLLinePrefix);
    ObjectsDeleteAll(0, PotentialSLLabelPrefix);
}

void DrawActivationLines()
{
    if (!ShowActivationLines || !EnableTrailing)
    {
        CleanActivationLines();
        return;
    }

    if (Profit <= 0)
    {
        CleanActivationLines();
        return;
    }

    datetime leftTime = GetLeftVisibleBarTime();

    // Collect tickets that should currently have an activation line.
    ulong activeTickets[];
    int activeCount = 0;

    for (int i = 0; i < OrdersTotal(); i++)
    {
        if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES) == false)
        {
            int Error = GetLastError();
            string ErrorText = ErrorDescription(Error);
            Print("ERROR - Unable to select the order - ", Error);
            Print("ERROR - ", ErrorText);
            continue;
        }
        int ticket = OrderTicket();
        if (OnlyCurrentSymbol && OrderSymbol() != Symbol()) continue;
        if (UseMagic && OrderMagicNumber() != MagicNumber) continue;
        if (UseComment && StringFind(OrderComment(), CommentFilter) < 0) continue;
        if (OnlyType != All && OrderType() != OnlyType) continue;

        string Instrument = OrderSymbol();
        double openPrice = OrderOpenPrice();
        int eDigits = (int)SymbolInfoInteger(Instrument, SYMBOL_DIGITS);
        double point = SymbolInfoDouble(Instrument, SYMBOL_POINT);
        double activationDist = Profit * point;
        if (activationDist == 0) continue;

        double activationLevel = 0;
        color lineColor = clrNONE;
        string dirLabel = "";
        if (OrderType() == OP_BUY)
        {
            activationLevel = NormalizeDouble(openPrice + activationDist, eDigits);
            // Skip activation lines that have already been crossed - trailing is active.
            if (SymbolInfoDouble(Instrument, SYMBOL_BID) >= activationLevel) continue;
            lineColor = ActivationBuyColor;
            dirLabel = "Buy";
        }
        else if (OrderType() == OP_SELL)
        {
            activationLevel = NormalizeDouble(openPrice - activationDist, eDigits);
            if (SymbolInfoDouble(Instrument, SYMBOL_ASK) <= activationLevel) continue;
            lineColor = ActivationSellColor;
            dirLabel = "Sell";
        }
        else continue; // Pending orders: no activation line.

        string lineName = ActivationLinePrefix + IntegerToString(ticket);
        string tooltip = "TSL Activation #" + IntegerToString(ticket) + " " + dirLabel + ": " + DoubleToString(activationLevel, eDigits);
        CreateOrMoveHLine(lineName, activationLevel, lineColor, ActivationStyle, ActivationWidth, tooltip);

        string labelName = ActivationLabelPrefix + IntegerToString(ticket);
        string labelText = "#" + IntegerToString(ticket) + " " + dirLabel + " TSL Activation";
        CreateOrMoveLabel(labelName, leftTime, activationLevel, labelText, lineColor, ActivationFontSize);

        ArrayResize(activeTickets, activeCount + 1);
        activeTickets[activeCount] = ticket;
        activeCount++;
    }

    // Remove activation lines + labels for orders that no longer exist or have activated.
    int totalObjects = ObjectsTotal(0, 0, OBJ_HLINE);
    for (int i = totalObjects - 1; i >= 0; i--)
    {
        string objName = ObjectName(0, i, 0, OBJ_HLINE);
        if (StringFind(objName, ActivationLinePrefix) != 0) continue;
        string ticketStr = StringSubstr(objName, StringLen(ActivationLinePrefix));
        ulong objTicket = (ulong)StringToInteger(ticketStr);
        bool found = false;
        for (int j = 0; j < activeCount; j++)
        {
            if (activeTickets[j] == objTicket)
            {
                found = true;
                break;
            }
        }
        if (!found)
        {
            ObjectDelete(0, objName);
            ObjectDelete(0, ActivationLabelPrefix + ticketStr);
        }
    }
    // Also clean orphaned labels (line was already removed).
    int totalText = ObjectsTotal(0, 0, OBJ_TEXT);
    for (int i = totalText - 1; i >= 0; i--)
    {
        string objName = ObjectName(0, i, 0, OBJ_TEXT);
        if (StringFind(objName, ActivationLabelPrefix) != 0) continue;
        string ticketStr = StringSubstr(objName, StringLen(ActivationLabelPrefix));
        ulong objTicket = (ulong)StringToInteger(ticketStr);
        bool found = false;
        for (int j = 0; j < activeCount; j++)
        {
            if (activeTickets[j] == objTicket)
            {
                found = true;
                break;
            }
        }
        if (!found) ObjectDelete(0, objName);
    }
}

void CleanActivationLines()
{
    ObjectsDeleteAll(0, ActivationLinePrefix);
    ObjectsDeleteAll(0, ActivationLabelPrefix);
}

// Time of the leftmost visible bar - used to anchor activation text labels.
datetime GetLeftVisibleBarTime()
{
    int firstVisibleBar = (int)ChartGetInteger(0, CHART_FIRST_VISIBLE_BAR);
    datetime barTime = iTime(Symbol(), PERIOD_CURRENT, firstVisibleBar);
    if (barTime == 0) barTime = TimeCurrent(); // Fallback.
    return barTime;
}

void CreateOrMoveHLine(string name, double price, color clr, ENUM_LINE_STYLE style, int width, string tooltip)
{
    ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
    ObjectSetDouble(0, name, OBJPROP_PRICE, price);
    ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, name, OBJPROP_STYLE, style);
    ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
    ObjectSetInteger(0, name, OBJPROP_BACK, true);
    ObjectSetString(0, name, OBJPROP_TOOLTIP, tooltip);
}

void CreateOrMoveLabel(string name, datetime time, double price, string text, color clr, int fontSize)
{
    ObjectCreate(0, name, OBJ_TEXT, 0, time, price);
    ObjectSetInteger(0, name, OBJPROP_TIME, time);
    ObjectSetDouble(0, name, OBJPROP_PRICE, price);
    ObjectSetString(0, name, OBJPROP_TEXT, text);
    ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
    ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

// Move EA-owned labels to the current leftmost visible bar so they follow the chart when the user scrolls or zooms.
void RepositionLabels()
{
    if (!ShowActivationLines && !ShowPotentialSLLines) return;

    datetime leftTime = GetLeftVisibleBarTime();
    int totalText = ObjectsTotal(0, 0, OBJ_TEXT);
    for (int i = totalText - 1; i >= 0; i--)
    {
        string objName = ObjectName(0, i, 0, OBJ_TEXT);
        if (StringFind(objName, ActivationLabelPrefix) != 0 &&
            StringFind(objName, PotentialSLLabelPrefix) != 0) continue;
        ObjectSetInteger(0, objName, OBJPROP_TIME, leftTime);
    }
    ChartRedraw();
}
//+------------------------------------------------------------------+