// -------------------------------------------------------------------------------
//   This cBot will start trailing the stop-loss after a given profit is reached.
//   WARNING: Use this software at your own risk.
//   The creator of this robot cannot be held responsible for any damage or loss.
//
//   Version 1.04
//   Copyright 2026, EarnForex.com
//   https://www.earnforex.com/metatrader-expert-advisors/Trailing-Stop-on-Profit/
// -------------------------------------------------------------------------------

using System;
using System.Linq;
using System.Collections.Generic;
using cAlgo.API;
using cAlgo.API.Internals;

namespace cAlgo.Robots
{
    [Robot(AccessRights = AccessRights.None)]
    public class TrailingStopOnProfit : Robot
    {
        // Expert advisor settings.
        [Parameter("Trailing Stop, points", Group = "Expert advisor settings", DefaultValue = 50, MinValue = 1)]
        public int TrailingStop { get; set; }
        
        [Parameter("Profit in points when TS should kick in", Group = "Expert advisor settings", DefaultValue = 100)]
        public int Profit { get; set; }

        [Parameter("Disable take-profit when TS kicks in?", Group = "Expert advisor settings", DefaultValue = false)]
        public bool DisableTPonTSL { get; set; }

        // Orders filtering options.
        [Parameter("Apply to current symbol only", Group = "Orders filtering options", DefaultValue = true)]
        public bool OnlyCurrentSymbol { get; set; }
        
        [Parameter("Apply to", Group = "Orders filtering options", DefaultValue = PositionTypeFilter.All)]
        public PositionTypeFilter OnlyType { get; set; }
        
        [Parameter("Filter by label", Group = "Orders filtering options", DefaultValue = false)]
        public bool UseLabel { get; set; }
        
        [Parameter("Label (if above is true)", Group = "Orders filtering options", DefaultValue = "")]
        public string LabelFilter { get; set; }
        
        [Parameter("Filter by comment", Group = "Orders filtering options", DefaultValue = false)]
        public bool UseComment { get; set; }
        
        [Parameter("Comment (if above is true)", Group = "Orders filtering options", DefaultValue = "")]
        public string CommentFilter { get; set; }
        
        [Parameter("Enable trailing stop", Group = "Orders filtering options", DefaultValue = false)]
        public bool EnableTrailingParam { get; set; }

        // Notification options.
        [Parameter("Enable notifications feature", Group = "Notification options", DefaultValue = false)]
        public bool EnableNotify { get; set; }
        
        [Parameter("Send alert notification", Group = "Notification options", DefaultValue = true)]
        public bool SendAlert { get; set; }
        
        [Parameter("Send notification via email", Group = "Notification options", DefaultValue = false)]
        public bool SendEmail { get; set; }

        [Parameter("Email Address", DefaultValue = "email@example.com", Group = "Notification options")]
        public string EmailAddress { get; set; }

        // Graphical window.
        [Parameter("Show graphical panel", Group = "Graphical window", DefaultValue = true)]
        public bool ShowPanel { get; set; }
        
        [Parameter("Expert name (to name the objects)", Group = "Graphical window", DefaultValue = "TSOP")]
        public string ExpertName { get; set; }
        
        [Parameter("Horizontal spacing for the control panel", Group = "Graphical window", DefaultValue = 20)]
        public int Xoff { get; set; }
        
        [Parameter("Vertical spacing for the control panel", Group = "Graphical window", DefaultValue = 20)]
        public int Yoff { get; set; }
        
        [Parameter("Chart Corner", Group = "Graphical window", DefaultValue = VerticalAlignment.Top)]
        public VerticalAlignment ChartCornerV { get; set; }
        
        [Parameter("Chart Corner", Group = "Graphical window", DefaultValue = HorizontalAlignment.Left)]
        public HorizontalAlignment ChartCornerH { get; set; }
        
        [Parameter("Font Size", Group = "Graphical window", DefaultValue = 14)]
        public int FontSize { get; set; }

        // Potential TSL Lines.
        [Parameter("Show potential TSL lines", Group = "Potential TSL Lines", DefaultValue = false)]
        public bool ShowPotentialSLLines { get; set; }

        [Parameter("Potential Buy TSL line color", Group = "Potential TSL Lines", DefaultValue = "DodgerBlue")]
        public Color PotentialSLBuyColor { get; set; }

        [Parameter("Potential Sell TSL line color", Group = "Potential TSL Lines", DefaultValue = "OrangeRed")]
        public Color PotentialSLSellColor { get; set; }

        [Parameter("Potential TSL line style", Group = "Potential TSL Lines", DefaultValue = LineStyle.Dots)]
        public LineStyle PotentialSLStyle { get; set; }

        [Parameter("Potential TSL line width", Group = "Potential TSL Lines", DefaultValue = 1, MinValue = 1)]
        public int PotentialSLWidth { get; set; }

        [Parameter("Potential TSL label font size", Group = "Potential TSL Lines", DefaultValue = 10, MinValue = 6)]
        public int PotentialSLLabelFontSize { get; set; }

        // Activation Lines.
        [Parameter("Show activation lines", Group = "Activation Lines", DefaultValue = false)]
        public bool ShowActivationLines { get; set; }

        [Parameter("Activation Buy line color", Group = "Activation Lines", DefaultValue = "DarkGray")]
        public Color ActivationBuyColor { get; set; }

        [Parameter("Activation Sell line color", Group = "Activation Lines", DefaultValue = "DarkSlateGray")]
        public Color ActivationSellColor { get; set; }

        [Parameter("Activation line style", Group = "Activation Lines", DefaultValue = LineStyle.Lines)]
        public LineStyle ActivationStyle { get; set; }

        [Parameter("Activation line width", Group = "Activation Lines", DefaultValue = 1, MinValue = 1)]
        public int ActivationWidth { get; set; }

        [Parameter("Activation label font size", Group = "Activation Lines", DefaultValue = 10, MinValue = 6)]
        public int ActivationFontSize { get; set; }

        public enum PositionTypeFilter
        {
            All = -1,     // All orders.
            Buy = 0,      // Buy only.
            Sell = 1      // Sell only.
        }

        private int OrderOpRetry = 5; // Number of position modification attempts.
        private bool EnableTrailing;
        
        // Panel objects.
        private TextBlock PanelLabel;
        private Button PanelEnableDisable;
        private StackPanel MainPanel;

        // Object-name prefixes - initialized in OnStart.
        private string PotentialSLLinePrefix;
        private string PotentialSLLabelPrefix;
        private string ActivationLinePrefix;
        private string ActivationLabelPrefix;

        protected override void OnStart()
        {
            EnableTrailing = EnableTrailingParam;

            PotentialSLLinePrefix = ExpertName + "-SL-";
            PotentialSLLabelPrefix = ExpertName + "-SLL-";
            ActivationLinePrefix = ExpertName + "-ACT-";
            ActivationLabelPrefix = ExpertName + "-ACTL-";

            if (ShowPanel) DrawPanel();

            DrawPotentialSLLines();
            DrawActivationLines();

            // Timer keeps lines refreshed and labels following the leftmost visible bar
            // during off-market hours and when the user scrolls/zooms the chart.
            if (ShowPotentialSLLines || ShowActivationLines)
            {
                Timer.Start(TimeSpan.FromSeconds(1));
            }
        }

        protected override void OnStop()
        {
            Timer.Stop();
            CleanPanel();
            CleanPotentialSLLines();
            CleanActivationLines();
        }

        protected override void OnTick()
        {
            if (EnableTrailing) DoTrailingStop();
            DrawPotentialSLLines();
            DrawActivationLines();
        }

        protected override void OnTimer()
        {
            DrawPotentialSLLines();
            DrawActivationLines();
        }

        private void DoTrailingStop()
        {
            var positions = Positions.ToArray();
            
            for (int i = positions.Length - 1; i >= 0; i--)
            {
                var position = positions[i];
                
                if (position == null) continue;
                
                // Filters.
                if ((OnlyCurrentSymbol) && (position.SymbolName != SymbolName)) continue;
                if ((UseLabel) && (position.Label != LabelFilter)) continue;
                if ((UseComment) && (position.Comment != null && !position.Comment.Contains(CommentFilter))) continue;
                if ((OnlyType != PositionTypeFilter.All) && 
                    ((OnlyType == PositionTypeFilter.Buy && position.TradeType != TradeType.Buy) ||
                     (OnlyType == PositionTypeFilter.Sell && position.TradeType != TradeType.Sell))) continue;

                Symbol symbol = Symbols.GetSymbol(position.SymbolName);
                
                // Normalize trailing stop value to the point value.
                double TSTP = TrailingStop * symbol.PipSize;
                double P = Profit * symbol.PipSize;
                
                double Bid = symbol.Bid;
                double Ask = symbol.Ask;
                double OpenPrice = position.EntryPrice;
                double StopLoss = position.StopLoss ?? 0;
                double TakeProfit = position.TakeProfit ?? 0;

                if (position.TradeType == TradeType.Buy)
                {
                    if (Math.Round(Bid - OpenPrice, symbol.Digits) >= Math.Round(P, symbol.Digits))
                    {
                        double new_sl = Math.Round(Bid - TSTP, symbol.Digits);
                        
                        // Adjust for tick size granularity.
                        if (symbol.TickSize > 0)
                        {
                            new_sl = Math.Round(Math.Round(new_sl / symbol.TickSize) * symbol.TickSize, symbol.Digits);
                        }
                        
                        if ((TSTP != 0) && (StopLoss < new_sl))
                        {
                            ModifyPosition(position, new_sl, TakeProfit);
                        }
                    }
                }
                else if (position.TradeType == TradeType.Sell)
                {
                    if (Math.Round(OpenPrice - Ask, symbol.Digits) >= Math.Round(P, symbol.Digits))
                    {
                        double new_sl = Math.Round(Ask + TSTP, symbol.Digits);
                        
                        // Adjust for tick size granularity.
                        if (symbol.TickSize > 0)
                        {
                            new_sl = Math.Round(Math.Round(new_sl / symbol.TickSize) * symbol.TickSize, symbol.Digits);
                        }
                        
                        if ((TSTP != 0) && ((StopLoss > new_sl) || (StopLoss == 0)))
                        {
                            ModifyPosition(position, new_sl, TakeProfit);
                        }
                    }
                }
            }
        }

        private void ModifyPosition(Position position, double SLPrice, double TPPrice)
        {
            for (int i = 1; i <= OrderOpRetry; i++) // Several attempts to modify the position.
            {
                var result = position.ModifyStopLossPrice(SLPrice);
                if (result.IsSuccessful)
                {
                    Print("TRADE - UPDATE SUCCESS - Order {0} new stop-loss {1}", position.Id, SLPrice);
                    string TP_Text = "";
                    if (DisableTPonTSL && TPPrice > 0)
                    {
                        result = position.ModifyTakeProfitPrice(0);
                        if (result.IsSuccessful)
                        {
                            Print("TRADE - UPDATE SUCCESS - Order {0} take-profit set to zero.", position.Id);
                            TP_Text = ". TP set to zero.";
                        }
                        else
                        {
                            Print("ERROR - UPDATE FAILED - error modifying order {0} return error: {1} Open={2} Old TP={3} New TP=0 Bid={4} Ask={5}",
                                position.Id, result.Error, position.EntryPrice, position.TakeProfit ?? 0,
                                Symbols.GetSymbol(position.SymbolName).Bid, Symbols.GetSymbol(position.SymbolName).Ask);
                            Print("ERROR - {0}", result.Error);
                        }
                    }
                    NotifyStopLossUpdate(position.Id, SLPrice, position.Symbol, TP_Text);
                    break;
                }
                else
                {
                    Print("ERROR - UPDATE FAILED - error modifying order {0} return error: {1} Open={2} Old SL={3} New SL={4} Bid={5} Ask={6}",
                        position.Id, result.Error, position.EntryPrice, position.StopLoss ?? 0, SLPrice,
                        Symbols.GetSymbol(position.SymbolName).Bid, Symbols.GetSymbol(position.SymbolName).Ask);
                    Print("ERROR - {0}", result.Error);
                }
            }
        }

        private void NotifyStopLossUpdate(long PositionId, double SLPrice, Symbol symbol, string TP_Text)
        {
            if (!EnableNotify) return;
            if (!SendAlert && !SendEmail) return;
            
            string EmailSubject = ExpertName + " " + SymbolName + " Notification";
            string EmailBody = Account.BrokerName + " - " + Account.Number + "\r\n\r\n" + 
                              ExpertName + " Notification for " + symbol + "\r\n\r\n";
            EmailBody += "Stop-loss for order " + PositionId + " moved to " + SLPrice.ToString("F" + symbol.Digits) + TP_Text;
            
            string AlertText = symbol.Name + " - Stop-loss for order " + PositionId + " moved to " + SLPrice.ToString("F" + symbol.Digits) + TP_Text;
            
            if (SendAlert) 
            {
                Notifications.ShowPopup(EmailSubject, AlertText, PopupNotificationState.Information);
            }
            if (SendEmail)
            {
                try 
                {
                    Notifications.SendEmail(EmailAddress, EmailAddress, EmailSubject, EmailBody);
                }
                catch (Exception e)
                {
                    Print("Error sending email: " + e.Message);
                }
            }
            Print(ExpertName + " - last notification sent on " + Server.Time.ToString());
        }

        private void DrawPanel()
        {
            int LeftOff = 0;
            int TopOff = 0;
            int RightOff = 0;
            int BottomOff = 0;
            if (ChartCornerH == HorizontalAlignment.Left) LeftOff = Xoff;
            else if (ChartCornerH == HorizontalAlignment.Right) RightOff = Xoff;
            if (ChartCornerV == VerticalAlignment.Top) TopOff = Yoff;
            else if (ChartCornerV == VerticalAlignment.Bottom) BottomOff = Yoff;
            MainPanel = new StackPanel 
            {
                Orientation = Orientation.Vertical,
                HorizontalAlignment = ChartCornerH,
                VerticalAlignment = ChartCornerV,
                Width = 200,
                MinHeight = 45,
                Margin = new Thickness(LeftOff, TopOff, RightOff, BottomOff),
                BackgroundColor = Color.White,
                Opacity = 0.9
            };

            PanelLabel = new TextBlock 
            {
                Text = "TSL on Profit",
                ForegroundColor = Color.Navy,
                BackgroundColor = Color.Khaki,
                Width = 198,
                MinHeight = 20,
                FontSize = FontSize,
                Margin = 1,
                HorizontalAlignment = HorizontalAlignment.Center,
                TextAlignment = TextAlignment.Center
            };

            PanelEnableDisable = new Button 
            {
                Text = EnableTrailing ? "TRAILING ENABLED" : "TRAILING DISABLED",
                ForegroundColor = Color.White,
                BackgroundColor = EnableTrailing ? Color.DarkGreen : Color.DarkRed,
                Width = 198,
                MinHeight = 20,
                FontSize = FontSize,
                CornerRadius = 0,
                HorizontalAlignment = HorizontalAlignment.Center
            };
            
            PanelEnableDisable.Click += ChangeTrailingEnabled;

            MainPanel.AddChild(PanelLabel);
            MainPanel.AddChild(PanelEnableDisable);
            
            Chart.AddControl(MainPanel);
        }

        private void UpdatePanel()
        {
            if (PanelEnableDisable != null)
            {
                PanelEnableDisable.Text = EnableTrailing ? "TRAILING ENABLED" : "TRAILING DISABLED";
                PanelEnableDisable.BackgroundColor = EnableTrailing ? Color.DarkGreen : Color.DarkRed;
            }
        }

        private void CleanPanel()
        {
            if (MainPanel != null)
            {
                Chart.RemoveControl(MainPanel);
            }
        }

        private void ChangeTrailingEnabled(ButtonClickEventArgs obj)
        {
            if (EnableTrailing == false)
            {
                EnableTrailing = true;
            }
            else 
            {
                EnableTrailing = false;
            }
            UpdatePanel();
            DrawActivationLines();
        }

        private void DrawPotentialSLLines()
        {
            if (!ShowPotentialSLLines)
            {
                CleanPotentialSLLines();
                return;
            }

            DateTime leftTime = GetLeftVisibleBarTime();

            var activeTickets = new HashSet<long>();

            foreach (var position in Positions)
            {
                if (position == null) continue;
                if (OnlyCurrentSymbol && position.SymbolName != SymbolName) continue;
                if (UseLabel && position.Label != LabelFilter) continue;
                if (UseComment && position.Comment != null && !position.Comment.Contains(CommentFilter)) continue;
                if (OnlyType != PositionTypeFilter.All &&
                    ((OnlyType == PositionTypeFilter.Buy && position.TradeType != TradeType.Buy) ||
                     (OnlyType == PositionTypeFilter.Sell && position.TradeType != TradeType.Sell))) continue;

                long ticket = position.Id;
                Symbol sym = Symbols.GetSymbol(position.SymbolName);
                double openPrice = position.EntryPrice;
                int digits = sym.Digits;
                double currentSL = position.StopLoss ?? 0;

                // Initial TSL = EntryPrice +/- (Profit - TrailingStop) * PipSize.
                // Rationale: trailing activates after price moves Profit*PipSize in favour;
                // at that instant the cBot places SL TrailingStop*PipSize on the safe side,
                // so the level depends only on EntryPrice and the inputs (i.e. fixed).
                double slDist = (Profit - TrailingStop) * sym.PipSize;
                double slLevel;
                Color lineColor;
                string dirLabel;

                if (position.TradeType == TradeType.Buy)
                {
                    slLevel = Math.Round(openPrice + slDist, digits);
                    // Skip if the position's SL has already been moved to (or beyond) the Initial TSL.
                    // StopLoss == 0 (no SL set) naturally fails this check, so the line is kept.
                    if (currentSL >= slLevel) continue;
                    lineColor = PotentialSLBuyColor;
                    dirLabel = "Buy";
                }
                else // Sell
                {
                    slLevel = Math.Round(openPrice - slDist, digits);
                    // For sells, "beyond" means a lower SL. Exclude StopLoss == 0 (no SL set).
                    if (currentSL > 0 && currentSL <= slLevel) continue;
                    lineColor = PotentialSLSellColor;
                    dirLabel = "Sell";
                }

                string lineName = PotentialSLLinePrefix + ticket;
                CreateOrMoveHLine(lineName, slLevel, lineColor, PotentialSLStyle, PotentialSLWidth);

                string labelName = PotentialSLLabelPrefix + ticket;
                string labelText = "#" + ticket + " " + dirLabel + " Initial TSL";
                CreateOrMoveLabel(labelName, leftTime, slLevel, labelText, lineColor, PotentialSLLabelFontSize);

                activeTickets.Add(ticket);
            }

            // Remove lines + labels for positions that no longer exist or are now filtered out.
            var toRemove = new List<string>();
            foreach (var obj in Chart.Objects)
            {
                if (obj.Name.StartsWith(PotentialSLLinePrefix))
                {
                    string ticketStr = obj.Name.Substring(PotentialSLLinePrefix.Length);
                    if (long.TryParse(ticketStr, out long t) && !activeTickets.Contains(t))
                    {
                        toRemove.Add(obj.Name);
                        toRemove.Add(PotentialSLLabelPrefix + ticketStr);
                    }
                }
                else if (obj.Name.StartsWith(PotentialSLLabelPrefix))
                {
                    string ticketStr = obj.Name.Substring(PotentialSLLabelPrefix.Length);
                    if (long.TryParse(ticketStr, out long t) && !activeTickets.Contains(t))
                    {
                        toRemove.Add(obj.Name);
                    }
                }
            }
            foreach (var name in toRemove)
            {
                Chart.RemoveObject(name);
            }
        }

        private void CleanPotentialSLLines()
        {
            var toRemove = new List<string>();
            foreach (var obj in Chart.Objects)
            {
                if (obj.Name.StartsWith(PotentialSLLinePrefix) || obj.Name.StartsWith(PotentialSLLabelPrefix))
                {
                    toRemove.Add(obj.Name);
                }
            }
            foreach (var name in toRemove)
            {
                Chart.RemoveObject(name);
            }
        }

        private void DrawActivationLines()
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

            DateTime leftTime = GetLeftVisibleBarTime();

            var activeTickets = new HashSet<long>();

            foreach (var position in Positions)
            {
                if (position == null) continue;
                if (OnlyCurrentSymbol && position.SymbolName != SymbolName) continue;
                if (UseLabel && position.Label != LabelFilter) continue;
                if (UseComment && position.Comment != null && !position.Comment.Contains(CommentFilter)) continue;
                if (OnlyType != PositionTypeFilter.All &&
                    ((OnlyType == PositionTypeFilter.Buy && position.TradeType != TradeType.Buy) ||
                     (OnlyType == PositionTypeFilter.Sell && position.TradeType != TradeType.Sell))) continue;

                long ticket = position.Id;
                Symbol sym = Symbols.GetSymbol(position.SymbolName);
                double openPrice = position.EntryPrice;
                int digits = sym.Digits;
                double activationDist = Profit * sym.PipSize;
                if (activationDist == 0) continue;

                double activationLevel;
                Color lineColor;
                string dirLabel;

                if (position.TradeType == TradeType.Buy)
                {
                    activationLevel = Math.Round(openPrice + activationDist, digits);
                    // Skip activation lines that have already been crossed - trailing is active.
                    if (sym.Bid >= activationLevel) continue;
                    lineColor = ActivationBuyColor;
                    dirLabel = "Buy";
                }
                else // Sell
                {
                    activationLevel = Math.Round(openPrice - activationDist, digits);
                    if (sym.Ask <= activationLevel) continue;
                    lineColor = ActivationSellColor;
                    dirLabel = "Sell";
                }

                string lineName = ActivationLinePrefix + ticket;
                CreateOrMoveHLine(lineName, activationLevel, lineColor, ActivationStyle, ActivationWidth);

                string labelName = ActivationLabelPrefix + ticket;
                string labelText = "#" + ticket + " " + dirLabel + " TSL Activation";
                CreateOrMoveLabel(labelName, leftTime, activationLevel, labelText, lineColor, ActivationFontSize);

                activeTickets.Add(ticket);
            }

            // Remove lines + labels for positions that no longer exist or have activated.
            var toRemove = new List<string>();
            foreach (var obj in Chart.Objects)
            {
                if (obj.Name.StartsWith(ActivationLinePrefix))
                {
                    string ticketStr = obj.Name.Substring(ActivationLinePrefix.Length);
                    if (long.TryParse(ticketStr, out long t) && !activeTickets.Contains(t))
                    {
                        toRemove.Add(obj.Name);
                        toRemove.Add(ActivationLabelPrefix + ticketStr);
                    }
                }
                else if (obj.Name.StartsWith(ActivationLabelPrefix))
                {
                    string ticketStr = obj.Name.Substring(ActivationLabelPrefix.Length);
                    if (long.TryParse(ticketStr, out long t) && !activeTickets.Contains(t))
                    {
                        toRemove.Add(obj.Name);
                    }
                }
            }
            foreach (var name in toRemove)
            {
                Chart.RemoveObject(name);
            }
        }

        private void CleanActivationLines()
        {
            var toRemove = new List<string>();
            foreach (var obj in Chart.Objects)
            {
                if (obj.Name.StartsWith(ActivationLinePrefix) || obj.Name.StartsWith(ActivationLabelPrefix))
                {
                    toRemove.Add(obj.Name);
                }
            }
            foreach (var name in toRemove)
            {
                Chart.RemoveObject(name);
            }
        }

        // Time of the leftmost visible bar - used to anchor text labels.
        private DateTime GetLeftVisibleBarTime()
        {
            int firstVisible = Chart.FirstVisibleBarIndex;
            if (firstVisible < 0) firstVisible = 0;
            if (firstVisible >= Bars.Count) firstVisible = Bars.Count - 1;
            return Bars.OpenTimes[firstVisible];
        }

        // Chart.DrawHorizontalLine updates an existing object with the same name,
        // so a single call handles both create and move.
        private void CreateOrMoveHLine(string name, double price, Color clr, LineStyle style, int width)
        {
            var line = Chart.DrawHorizontalLine(name, price, clr, width, style);
            line.IsInteractive = false;
        }

        // Label is anchored at the leftmost visible bar so it stays in view as the
        // user scrolls. HorizontalAlignment.Right + VerticalAlignment.Top puts the
        // text just above and to the right of the anchor point (bottom-left anchored).
        private void CreateOrMoveLabel(string name, DateTime time, double price, string text, Color clr, int fontSize)
        {
            var label = Chart.DrawText(name, text, time, price, clr);
            label.FontSize = fontSize;
            label.HorizontalAlignment = HorizontalAlignment.Right;
            label.VerticalAlignment = VerticalAlignment.Top;
            label.IsInteractive = false;
        }
    }
}