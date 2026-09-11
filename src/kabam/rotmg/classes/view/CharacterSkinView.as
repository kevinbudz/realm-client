package kabam.rotmg.classes.view
{
   import com.company.assembleegameclient.screens.AccountScreen;
   import com.company.assembleegameclient.screens.TitleMenuOption;
   import com.company.assembleegameclient.ui.layout.MenuBackground;
   import com.company.assembleegameclient.ui.layout.MenuFrame;
   import com.company.assembleegameclient.ui.layout.ScaledScreen;
   import flash.display.Graphics;
   import flash.display.Shape;
   import flash.events.MouseEvent;
   import kabam.rotmg.game.view.CreditDisplay;
   import org.osflash.signals.Signal;
   import org.osflash.signals.natives.NativeMappedSignal;

   public class CharacterSkinView extends ScaledScreen
   {
      private var creditsDisplay:CreditDisplay;
      private var dividerLine:Shape;
      private var playBtn:TitleMenuOption;
      private var backBtn:TitleMenuOption;
      private var list:CharacterSkinListView;
      private var detail:ClassDetailView;
      public var play:Signal;
      public var back:Signal;

      public function CharacterSkinView()
      {
         super();
         setBackground(new MenuBackground());
         addFrame(new MenuFrame());
         this.chrome.addChild(new AccountScreen());
         this.makeCreditDisplay();
         this.makeDividerLine();
         this.makeLines();
         this.makePlayButton();
         this.makeBackButton();
         this.makeListView();
         this.makeClassDetailView();
         this.play = new NativeMappedSignal(this.playBtn,MouseEvent.CLICK);
         this.back = new NativeMappedSignal(this.backBtn,MouseEvent.CLICK);
         this.layout();
      }

      private function makeCreditDisplay() : void
      {
         this.creditsDisplay = new CreditDisplay();
         this.chrome.addChild(this.creditsDisplay);
      }

      private function makeDividerLine() : void
      {
         this.dividerLine = new Shape();
         this.chrome.addChild(this.dividerLine);
      }

      private function makeLines() : void
      {
         var shape:Shape = new Shape();
         shape.graphics.clear();
         shape.graphics.lineStyle(2,5526612);
         shape.graphics.moveTo(346,105);
         shape.graphics.lineTo(346,526);
         this.content.addChild(shape);
      }

      private function makePlayButton() : void
      {
         this.playBtn = new TitleMenuOption("play",36,false);
         this.playBtn.x = 400 - this.playBtn.width / 2;
         this.playBtn.y = 520;
         this.content.addChild(this.playBtn);
      }

      private function makeBackButton() : void
      {
         this.backBtn = new TitleMenuOption("back",22,false);
         this.backBtn.x = 30;
         this.backBtn.y = 534;
         this.content.addChild(this.backBtn);
      }

      private function makeListView() : void
      {
         this.list = new CharacterSkinListView();
         this.list.x = 351;
         this.list.y = 110;
         this.content.addChild(this.list);
      }

      private function makeClassDetailView() : void
      {
         this.detail = new ClassDetailView();
         this.detail.x = 5;
         this.detail.y = 110;
         this.content.addChild(this.detail);
      }

      override protected function layoutChrome(stageWidth:Number, stageHeight:Number, scale:Number) : void
      {
         if (this.creditsDisplay != null)
         {
            this.creditsDisplay.scaleX = scale;
            this.creditsDisplay.scaleY = scale;
            this.creditsDisplay.x = stageWidth;
            this.creditsDisplay.y = 20 * scale;
         }
         var g:Graphics = this.dividerLine.graphics;
         g.clear();
         g.lineStyle(2 * scale,5526612);
         g.moveTo(0,105 * scale);
         g.lineTo(stageWidth,105 * scale);
         g.lineStyle();
      }

      public function setPlayButtonEnabled(activate:Boolean):void {
         if (!activate) {
            this.playBtn.deactivate();
         }
      }
   }
}
