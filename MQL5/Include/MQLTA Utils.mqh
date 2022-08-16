#property link          "https://www.earnforex.com/"
#property version       "1.00"
#property strict
#property copyright     "EarnForex.com - 2020"
#property description   ""
#property description   ""
#property description   ""
#property description   ""
#property description   "Find More on EarnForex.com"

#define OP_BUY 0           //Buy 
#define OP_SELL 1          //Sell 
#define OP_BUYLIMIT 2      //Pending order of BUY LIMIT type 
#define OP_SELLLIMIT 3     //Pending order of SELL LIMIT type 
#define OP_BUYSTOP 4       //Pending order of BUY STOP type 
#define OP_SELLSTOP 5      //Pending order of SELL STOP type 
//---
#define MODE_OPEN 0
#define MODE_CLOSE 3
#define MODE_VOLUME 4 
#define MODE_REAL_VOLUME 5
#define MODE_TRADES 0
#define MODE_HISTORY 1
#define SELECT_BY_POS 0
#define SELECT_BY_TICKET 1
//---
#define DOUBLE_VALUE 0
#define FLOAT_VALUE 1
#define LONG_VALUE INT_VALUE
//---
#define CHART_BAR 0
#define CHART_CANDLE 1
//---
#define MODE_ASCEND 0
#define MODE_DESCEND 1
//---
#define MODE_LOW 1
#define MODE_HIGH 2
#define MODE_TIME 5
#define MODE_BID 9
#define MODE_ASK 10
#define MODE_POINT 11
#define MODE_DIGITS 12
#define MODE_SPREAD 13
#define MODE_STOPLEVEL 14
#define MODE_LOTSIZE 15
#define MODE_TICKVALUE 16
#define MODE_TICKSIZE 17
#define MODE_SWAPLONG 18
#define MODE_SWAPSHORT 19
#define MODE_STARTING 20
#define MODE_EXPIRATION 21
#define MODE_TRADEALLOWED 22
#define MODE_MINLOT 23
#define MODE_LOTSTEP 24
#define MODE_MAXLOT 25
#define MODE_SWAPTYPE 26
#define MODE_PROFITCALCMODE 27
#define MODE_MARGINCALCMODE 28
#define MODE_MARGININIT 29
#define MODE_MARGINMAINTENANCE 30
#define MODE_MARGINHEDGED 31
#define MODE_MARGINREQUIRED 32

enum ENUM_HOUR{
   h00=00,     //00:00
   h01=01,     //01:00
   h02=02,     //02:00
   h03=03,     //03:00
   h04=04,     //04:00
   h05=05,     //05:00
   h06=06,     //06:00
   h07=07,     //07:00
   h08=08,     //08:00
   h09=09,     //09:00
   h10=10,     //10:00
   h11=11,     //11:00
   h12=12,     //12:00
   h13=13,     //13:00
   h14=14,     //14:00
   h15=15,     //15:00
   h16=16,     //16:00
   h17=17,     //17:00
   h18=18,     //18:00
   h19=19,     //19:00
   h20=20,     //20:00
   h21=21,     //21:00
   h22=22,     //22:00
   h23=23,     //23:00
};

ENUM_TIMEFRAMES TimeFrames[]={
   PERIOD_M1,
   PERIOD_M2,
   PERIOD_M3,
   PERIOD_M4,
   PERIOD_M5,
   PERIOD_M6,
   PERIOD_M10,
   PERIOD_M12,
   PERIOD_M15,
   PERIOD_M20,
   PERIOD_M30,
   PERIOD_H1,
   PERIOD_H2,
   PERIOD_H3,
   PERIOD_H4,
   PERIOD_H6,
   PERIOD_H8,
   PERIOD_H12,
   PERIOD_D1,
   PERIOD_W1,
   PERIOD_MN1
   };
   

//Return the index of the requested time frame in the array TimeFrames
int TimeFrameIndex(ENUM_TIMEFRAMES TimeFrame){
   int j=0;
   if(TimeFrame==PERIOD_CURRENT) TimeFrame=Period();
   for(int i=0;i<ArraySize(TimeFrames);i++){
      if(TimeFrame==TimeFrames[i]) return i;
   }
   return j;
}

//Check if the current time is within the period
bool IsCurrentTimeInInterval(ENUM_HOUR Start,ENUM_HOUR End){
   if(Start==End && Hour()==Start) return true;
   if(Start<End && Hour()>=Start && Hour()<=End) return true;
   if(Start>End && ((Hour()>=Start && Hour()<=23) || (Hour()<=End && Hour()>=0))) return true;
   return false;
}


//Check if the software is over the date of use, throw a message and return true if it is
bool UpdateCheckOver(string Name, datetime ExpiryDate, bool ShowAlert){
   if(TimeCurrent()>ExpiryDate){
      string EditText="Version Expired, This Product Must Be Updated";
      string AlertText="Version Expired, Please Download The New Version From MQL4TradingAutomation.com";
      DrawExpiry(Name,EditText); 
      if(ShowAlert){
         Alert(AlertText);
         Print(AlertText);    
      }
      return true;
   }
   else return false;
}

//Check if the software is over the warning date and throw a message if it is
void UpdateCheckWarning(string Name, datetime WarnDate, datetime ExpDate, bool ShowAlert){
   if(TimeCurrent()>WarnDate){
      MqlDateTime WarningDate,ExpiryDate; 
      TimeToStruct(WarnDate,WarningDate); 
      TimeToStruct(ExpDate,ExpiryDate); 
      string WarningDateStr=(string)ExpiryDate.day+"/"+(string)ExpiryDate.mon+"/"+(string)ExpiryDate.year;
      string EditText="This Product Version Will Stop Working On The "+WarningDateStr+"";
      string AlertText="This Product Version Will Stop Working On The "+WarningDateStr+", Please Download The New Version From MQL4TradingAutomation.com";
      DrawExpiry(Name,EditText); 
      if(ShowAlert){
         Alert(AlertText);
         Print(AlertText);    
      }
   }
}

//Draw a box to advise of the warning/expiry of the product
void DrawExpiry(string Name, string Text){
   string TextBoxName=Name+"ExpirationTextBox";
   if(ObjectFind(0,TextBoxName)<0){
      DrawEdit(TextBoxName,20,20,300,20,true,8,"",ALIGN_CENTER,"Arial",Text,true,clrNavy,clrKhaki,clrBlack);
   }
}

//Draw an edit box with the specified parameters
void DrawEdit( string Name, 
               int XStart,
               int YStart,
               int Width,
               int Height,
               bool ReadOnly,
               int EditFontSize,
               string Tooltip,
               int Align,
               string EditFont,
               string Text,
               bool Selectable, 
               color TextColor=clrBlack,
               color BGColor=clrWhiteSmoke,
               color BDColor=clrBlack
   ){

   ObjectCreate(0,Name,OBJ_EDIT,0,0,0);
   ObjectSetInteger(0,Name,OBJPROP_XDISTANCE,XStart);
   ObjectSetInteger(0,Name,OBJPROP_YDISTANCE,YStart);
   ObjectSetInteger(0,Name,OBJPROP_XSIZE,Width);
   ObjectSetInteger(0,Name,OBJPROP_YSIZE,Height);
   ObjectSetInteger(0,Name,OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,Name,OBJPROP_STATE,false);
   ObjectSetInteger(0,Name,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,Name,OBJPROP_READONLY,ReadOnly);
   ObjectSetInteger(0,Name,OBJPROP_FONTSIZE,EditFontSize);
   ObjectSetString(0,Name,OBJPROP_TOOLTIP,Tooltip);
   ObjectSetInteger(0,Name,OBJPROP_ALIGN,Align);
   ObjectSetString(0,Name,OBJPROP_FONT,EditFont);
   ObjectSetString(0,Name,OBJPROP_TEXT,Text);
   ObjectSetInteger(0,Name,OBJPROP_SELECTABLE,Selectable);
   ObjectSetInteger(0,Name,OBJPROP_COLOR,TextColor);
   ObjectSetInteger(0,Name,OBJPROP_BGCOLOR,BGColor);
   ObjectSetInteger(0,Name,OBJPROP_BORDER_COLOR,BDColor);
}


string AccountCompany(){
   return AccountInfoString(ACCOUNT_COMPANY);
}


string AccountName(){
   return AccountInfoString(ACCOUNT_NAME);
}


long AccountNumber(){
   return AccountInfoInteger(ACCOUNT_LOGIN);
}

string AccountCurrency(){
   return AccountInfoString(ACCOUNT_CURRENCY);
}

double AccountBalance(){
   return AccountInfoDouble(ACCOUNT_BALANCE);
}

double AccountEquity(){
   return AccountInfoDouble(ACCOUNT_EQUITY);
}

double AccountFreeMargin(){
   return AccountInfoDouble(ACCOUNT_MARGIN_FREE);
}

void SetIndex(int Index, int Type, int Style, int Width, int Color, string Label){
   PlotIndexSetInteger(Index,PLOT_DRAW_TYPE,Type);
   PlotIndexSetInteger(Index,PLOT_LINE_STYLE,Style);
   PlotIndexSetInteger(Index,PLOT_LINE_WIDTH,Width);
   PlotIndexSetInteger(Index,PLOT_LINE_COLOR,Color);
   PlotIndexSetString(Index,PLOT_LABEL,Label);
}

int WindowFind(string Name){
   return ChartWindowFind(0,Name);
}

string TimeFrameDescription(int TimeFrame){
   string perioddesc="";
   switch (TimeFrame){
      case PERIOD_M1: 
         perioddesc="M1";
         break;
      case PERIOD_M2: 
         perioddesc="M2";
         break;
      case PERIOD_M3: 
         perioddesc="M3";
         break;
      case PERIOD_M4: 
         perioddesc="M4";
         break;
      case PERIOD_M5: 
         perioddesc="M5";
         break;
      case PERIOD_M6: 
         perioddesc="M6";
         break;
      case PERIOD_M10: 
         perioddesc="M10";
         break;
      case PERIOD_M12: 
         perioddesc="M12";
         break;
      case PERIOD_M15: 
         perioddesc="M15";
         break;
      case PERIOD_M20: 
         perioddesc="M20";
         break;
      case PERIOD_M30: 
         perioddesc="M30";
         break;
      case PERIOD_H1: 
         perioddesc="H1";
         break;
      case PERIOD_H2: 
         perioddesc="H2";
         break;
      case PERIOD_H3: 
         perioddesc="H3";
         break;
      case PERIOD_H4: 
         perioddesc="H4";
         break;
      case PERIOD_H6: 
         perioddesc="H6";
         break;
      case PERIOD_H8: 
         perioddesc="H8";
         break;
      case PERIOD_H12: 
         perioddesc="H12";
         break;
      case PERIOD_D1: 
         perioddesc="D1";
         break;
      case PERIOD_W1: 
         perioddesc="W1";
         break;
      case PERIOD_MN1: 
         perioddesc="MN1";
         break;
   }
   return perioddesc;
}


string OrderSymbol(){
    return OrderGetString(ORDER_SYMBOL);
}

long OrderMagicNumber(){
   return OrderGetInteger(ORDER_MAGIC);
}

double OrderStopLoss(){
   return OrderGetDouble(ORDER_SL);
}

double OrderTakeProfit(){
   return OrderGetDouble(ORDER_TP);
}

ENUM_ORDER_TYPE OrderType(){
   return (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
}

long OrderTicket(){
   return OrderGetInteger(ORDER_TICKET);
}

long OrderOpenTime(){
   return OrderGetInteger(ORDER_TIME_DONE);
}

double OrderOpenPrice(){
   return OrderGetDouble(ORDER_PRICE_OPEN);
}

double OrderLots(){
   return OrderGetDouble(ORDER_VOLUME_CURRENT);
}

int Hour(){
   MqlDateTime mTime;
   TimeCurrent(mTime);
   return(mTime.hour);
}