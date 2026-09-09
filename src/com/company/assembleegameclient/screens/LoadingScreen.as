package com.company.assembleegameclient.screens
{
   import com.company.assembleegameclient.ui.layout.LayoutHelper;
   import com.company.assembleegameclient.ui.layout.MenuBackground;
   import com.company.assembleegameclient.ui.layout.MenuFrame;
   import com.company.assembleegameclient.ui.layout.ScaledScreen;
   import com.company.ui.SimpleText;
   import flash.filters.DropShadowFilter;
   import flash.text.TextFieldAutoSize;

   public class LoadingScreen extends ScaledScreen
   {
       
      
      private var text:SimpleText;
      
      public function LoadingScreen()
      {
         super();
         setBackground(new MenuBackground());
         addFrame(new MenuFrame());
         this.text = new SimpleText(30,16777215,false,0,0);
         this.text.y = 526;
         this.text.setBold(true);
         this.text.htmlText = "<p align=\"center\">Loading...</p>";
         this.text.autoSize = TextFieldAutoSize.CENTER;
         this.text.updateMetrics();
         this.text.filters = [new DropShadowFilter(0,0,0,1,4,4)];
         this.text.x = LayoutHelper.centerX(this.text.width);
         this.content.addChild(this.text);
      }

      public function setText(value:String) : void
      {
         this.text.htmlText = value;
         this.text.x = LayoutHelper.centerX(this.text.width);
      }
   }
}
