package kabam.rotmg.ui.view
{
   import com.company.assembleegameclient.constants.ScreenTypes;
import com.company.assembleegameclient.parameters.Parameters;
import com.company.assembleegameclient.screens.AccountScreen;
   import com.company.assembleegameclient.screens.TitleMenuOption;
   import com.company.assembleegameclient.ui.layout.LayoutHelper;
   import com.company.assembleegameclient.ui.layout.MenuBackground;
   import com.company.assembleegameclient.ui.layout.MenuFrame;
   import com.company.assembleegameclient.ui.layout.ScaledScreen;
   import com.company.ui.SimpleText;
   import flash.display.Bitmap;
   import flash.display.Sprite;
   import flash.filters.DropShadowFilter;

import org.osflash.signals.Signal;

   public class TitleView extends ScaledScreen
   {
      private static const COPYRIGHT:String = "© 2010, 2011 by Wild Shadow Studios, Inc.";
       
      
      public var playClicked:Signal;
      public var accountClicked:Signal;
      public var legendsClicked:Signal;
      public var editorClicked:Signal;

      private var container:Sprite;

      private var logo:Bitmap;

      private var playButton:TitleMenuOption;
      private var accountButton:TitleMenuOption;
      private var legendsButton:TitleMenuOption;
      private var editorButton:TitleMenuOption;

      private var versionText:SimpleText;
      private var copyrightText:SimpleText;

      public function TitleView()
      {
         super();
         setBackground(new MenuBackground());
         addFrame(new MenuFrame());
         this.chrome.addChild(new AccountScreen());
         this.makeChildren();
      }
      
      private function makeChildren() : void
      {
         this.container = new Sprite();
         this.logo = new TitleView_Logo();
         this.logo.smoothing = true;
         this.logo.x = LayoutHelper.centerX(this.logo.width);
         this.logo.y = 83;
         this.container.addChild(this.logo);
         this.playButton = new TitleMenuOption(ScreenTypes.PLAY,36,true);
         this.playClicked = this.playButton.clicked;
         this.container.addChild(this.playButton);
         this.accountButton = new TitleMenuOption(ScreenTypes.ACCOUNT,22,false);
         this.accountClicked = this.accountButton.clicked;
         this.container.addChild(this.accountButton);
         this.legendsButton = new TitleMenuOption(ScreenTypes.LEGENDS,22,false);
         this.legendsClicked = this.legendsButton.clicked;
         this.container.addChild(this.legendsButton);
         this.editorButton = new TitleMenuOption(ScreenTypes.EDITOR,22,false);
         this.editorClicked = this.editorButton.clicked;
         this.container.addChild(editorButton);
         this.versionText = new SimpleText(12,8355711,false,0,0);
         this.versionText.filters = [new DropShadowFilter(0,0,0)];
         this.chrome.addChild(this.versionText);
         this.copyrightText = new SimpleText(12,8355711,false,0,0);
         this.copyrightText.text = COPYRIGHT;
         this.copyrightText.updateMetrics();
         this.copyrightText.filters = [new DropShadowFilter(0,0,0)];
         this.chrome.addChild(this.copyrightText);
      }

      public function initialize() : void
      {
         this.updateVersionText();
         this.positionButtons();
         this.addChildren();
         this.layout();
      }
      
      private function updateVersionText() : void
      {
         this.versionText.htmlText = "RotMG " + Parameters.BUILD_VERSION;
         this.versionText.updateMetrics();
      }
      
      private function addChildren() : void
      {
         this.content.addChild(this.container);
      }

      private function positionButtons() : void
      {
         this.playButton.x = LayoutHelper.centerX(this.playButton.width);
         this.playButton.y = 520;
         this.accountButton.x = LayoutHelper.centerX(this.accountButton.width) - 94;
         this.accountButton.y = 532;
         this.legendsButton.x = LayoutHelper.centerX(this.legendsButton.width) + 96;
         this.legendsButton.y = 532;
         this.editorButton.x = 8;
         this.editorButton.y = 532;
         this.layout();
      }

      override protected function layoutChrome(stageWidth:Number, stageHeight:Number, scale:Number) : void
      {
         this.versionText.scaleX = scale;
         this.versionText.scaleY = scale;
         this.versionText.x = 0;
         this.versionText.y = stageHeight - this.versionText.height;
         this.copyrightText.scaleX = scale;
         this.copyrightText.scaleY = scale;
         this.copyrightText.x = stageWidth - this.copyrightText.width;
         this.copyrightText.y = stageHeight - this.copyrightText.height;
      }
   }
}
