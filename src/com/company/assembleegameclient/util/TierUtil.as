package com.company.assembleegameclient.util
{
   import com.company.assembleegameclient.objects.ObjectLibrary;
   import com.company.assembleegameclient.ui.tooltip.TooltipHelper;
   import com.company.ui.SimpleText;

   public class TierUtil
   {


      public function TierUtil()
      {
         super();
      }

      public static function getTierTag(objectType:int, size:int = 12) : SimpleText
      {
         var objectXML:XML = ObjectLibrary.xmlLibrary_[objectType];
         if(objectXML == null)
         {
            return null;
         }
         if(objectXML.hasOwnProperty("Consumable") || isPet(objectXML)
            || objectXML.hasOwnProperty("Treasure") || objectXML.hasOwnProperty("PetFood")
            || objectXML.hasOwnProperty("NoTierTag"))
         {
            return null;
         }
         var tag:SimpleText = new SimpleText(size,16777215,false,0,0);
         tag.setBold(true);
         if(objectXML.hasOwnProperty("Tier"))
         {
            tag.text = "T" + objectXML.Tier;
         }
         else if(objectXML.hasOwnProperty("@setType"))
         {
            tag.setColor(TooltipHelper.SET_COLOR);
            tag.text = "ST";
         }
         else
         {
            tag.setColor(TooltipHelper.UNTIERED_COLOR);
            tag.text = "UT";
         }
         tag.updateMetrics();
         return tag;
      }

      public static function isPet(itemXML:XML) : Boolean
      {
         var activateTags:XMLList = itemXML.Activate.(text() == "PermaPet");
         return activateTags.length() >= 1;
      }
   }
}
