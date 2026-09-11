package com.company.assembleegameclient.ui.tooltip
{
   public class TooltipHelper
   {
      public static const DEFAULT_COLOR:String = "#FFFF8F";
      public static const BETTER_COLOR:String = "#00ff00";
      public static const WORSE_COLOR:String = "#ff0000";
      public static const NO_DIFF_COLOR:String = "#FFFF8F";
      public static const SPECIAL_COLOR:String = "#8A2BE2";
      public static const WISMOD_COLOR:String = "#4063E3";
      public static const UNTIERED_COLOR:uint = 0x8A2BE2;
      public static const SET_COLOR:uint = 0xFF9900;
      public static const SET_COLOR_INACTIVE:String = "6835752";

      public function TooltipHelper()
      {
         super();
      }
      
      public static function wrapInFontTag(text:String, color:String) : String
      {
         var tagStr:String = "<font color=\"" + color + "\">" + text + "</font>";
         return tagStr;
      }
      
      public static function getFormattedString(value:Number) : String
      {
         var formatted:Number = int((value)*1000)/1000;
         return formatted.toString();
      }
   }
}
