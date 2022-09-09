#property link          "https://www.earnforex.com/"
#property version       "1.01"
#property strict
#property copyright     "EarnForex.com - 2020-2021"
#property description   ""
#property description   ""
#property description   ""
#property description   ""
#property description   "Find More on EarnForex.com"

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
               color TextColor = clrBlack,
               color BGColor = clrWhiteSmoke,
               color BDColor = clrBlack
             )
{

    if (ObjectFind(0, Name) < 0) ObjectCreate(0, Name, OBJ_EDIT, 0, 0, 0);
    ObjectSetInteger(0, Name, OBJPROP_XDISTANCE, XStart);
    ObjectSetInteger(0, Name, OBJPROP_YDISTANCE, YStart);
    ObjectSetInteger(0, Name, OBJPROP_XSIZE, Width);
    ObjectSetInteger(0, Name, OBJPROP_YSIZE, Height);
    ObjectSetInteger(0, Name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, Name, OBJPROP_STATE, false);
    ObjectSetInteger(0, Name, OBJPROP_HIDDEN, true);
    ObjectSetInteger(0, Name, OBJPROP_READONLY, ReadOnly);
    ObjectSetInteger(0, Name, OBJPROP_FONTSIZE, EditFontSize);
    ObjectSetString(0, Name, OBJPROP_TOOLTIP, Tooltip);
    ObjectSetInteger(0, Name, OBJPROP_ALIGN, Align);
    ObjectSetString(0, Name, OBJPROP_FONT, EditFont);
    ObjectSetString(0, Name, OBJPROP_TEXT, Text);
    ObjectSetInteger(0, Name, OBJPROP_SELECTABLE, Selectable);
    ObjectSetInteger(0, Name, OBJPROP_COLOR, TextColor);
    ObjectSetInteger(0, Name, OBJPROP_BGCOLOR, BGColor);
    ObjectSetInteger(0, Name, OBJPROP_BORDER_COLOR, BDColor);
    ObjectSetInteger(0, Name, OBJPROP_BACK, false);
}
//+------------------------------------------------------------------+