// -------------------------------------------------------------------------------
//   This cBot will start trailing the stop-loss after a given profit is reached.
//   WARNING: Use this software at your own risk.
//   The creator of this robot cannot be held responsible for any damage or loss.
//
//   Version 1.03
//   Copyright 2025, EarnForex.com
//   https://www.earnforex.com/metatrader-expert-advisors/Trailing-Stop-on-Profit/
// -------------------------------------------------------------------------------

using System;
using System.Linq;
using cAlgo.API;
using cAlgo.API.Internals;

namespace cAlgo.Robots
{
    [Robot(AccessRights = AccessRights.None)]
    public class TrailingStopOnProfit : Robot
    {
        // Expert advisor settings.
        [Parameter("Trailing Stop, points", Group = "Expert advisor settings", DefaultValue = 50)]
        public int TrailingStop { get; set; }
        
        [Parameter("Profit in points when TS should kick in", Group = "Expert advisor settings", DefaultValue = 100)]
        public int Profit { get; set; }

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
        
        [Parameter("Send notification via email", Group = "Notification options", DefaultValue = true)]
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

        protected override void OnStart()
        {
            EnableTrailing = EnableTrailingParam;
            
            if (ShowPanel) DrawPanel();
        }

        protected override void OnStop()
        {
            CleanPanel();
        }

        protected override void OnTick()
        {
            if (EnableTrailing) DoTrailingStop();
            if (ShowPanel) UpdatePanel();
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
                    NotifyStopLossUpdate(position.Id, SLPrice, position.SymbolName);
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

        private void NotifyStopLossUpdate(long PositionId, double SLPrice, string symbol)
        {
            if (!EnableNotify) return;
            if ((!SendAlert) && (!SendEmail)) return;
            
            string EmailSubject = ExpertName + " " + SymbolName + " Notification";
            string EmailBody = Account.BrokerName + " - " + Account.Number + "\r\n\r\n" + 
                              ExpertName + " Notification for " + symbol + "\r\n\r\n";
            EmailBody += "Stop-loss for order " + PositionId + " moved to " + SLPrice.ToString("F" + Symbol.Digits);
            
            string AlertText = symbol + " - Stop-loss for order " + PositionId + " moved to " + SLPrice.ToString("F" + Symbol.Digits);
            
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
        }
    }
}