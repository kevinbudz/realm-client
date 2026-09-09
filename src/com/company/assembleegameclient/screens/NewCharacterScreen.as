package com.company.assembleegameclient.screens
{
   import com.company.assembleegameclient.appengine.SavedCharactersList;
   import com.company.assembleegameclient.objects.ObjectLibrary;
   import com.company.assembleegameclient.ui.layout.LayoutHelper;
   import com.company.assembleegameclient.ui.layout.MenuBackground;
   import com.company.assembleegameclient.ui.layout.MenuFrame;
   import com.company.assembleegameclient.ui.layout.ScaledScreen;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.events.MouseEvent;
   import kabam.rotmg.core.model.PlayerModel;
   import kabam.rotmg.game.view.CreditDisplay;
   import org.osflash.signals.Signal;

   public class NewCharacterScreen extends ScaledScreen
   {
      private var backButton_:TitleMenuOption;
      private var creditDisplay_:CreditDisplay;
      private var boxes_:Object;
      public var tooltip:Signal;
      public var close:Signal;
      public var selected:Signal;
      
      private var isInitialized:Boolean = false;
      
      public function NewCharacterScreen()
      {
         this.boxes_ = {};
         super();
         this.tooltip = new Signal(Sprite);
         this.selected = new Signal(int);
         this.close = new Signal();
         setBackground(new MenuBackground());
         addFrame(new MenuFrame());
         this.chrome.addChild(new AccountScreen());
      }
      
      public function initialize(model:PlayerModel) : void
      {
         var playerXML:XML = null;
         var objectType:int = 0;
         var characterType:String = null;
         var charBox:CharacterBox = null;
         if(this.isInitialized)
         {
            return;
         }
         this.isInitialized = true;
         this.backButton_ = new TitleMenuOption("back",36,false);
         this.backButton_.addEventListener(MouseEvent.CLICK,this.onBackClick);
         this.content.addChild(this.backButton_);
         this.creditDisplay_ = new CreditDisplay();
         this.creditDisplay_.draw(model.getCredits(),model.getFame());
         this.chrome.addChild(this.creditDisplay_);
         for(var i:int = 0; i < ObjectLibrary.playerChars_.length; i++)
         {
            playerXML = ObjectLibrary.playerChars_[i];
            objectType = int(playerXML.@type);
            characterType = playerXML.@id;

            charBox = new CharacterBox(playerXML,model.getCharStats()[objectType],model);
            charBox.x = 50 + 140 * int(i % 5) + 70 - charBox.width / 2;
            charBox.y = 88 + 140 * int(i / 5);
            this.boxes_[objectType] = charBox;
            charBox.addEventListener(MouseEvent.ROLL_OVER,this.onCharBoxOver);
            charBox.addEventListener(MouseEvent.ROLL_OUT,this.onCharBoxOut);
            charBox.characterSelectClicked_.add(this.onCharBoxClick);
            this.content.addChild(charBox);
         }
         this.backButton_.x = LayoutHelper.centerX(this.backButton_.width);
         this.backButton_.y = 524;
         this.layout();
      }

      override protected function layoutChrome(stageWidth:Number, stageHeight:Number, scale:Number) : void
      {
         if (this.creditDisplay_ != null)
         {
            this.creditDisplay_.scaleX = scale;
            this.creditDisplay_.scaleY = scale;
            this.creditDisplay_.x = stageWidth;
            this.creditDisplay_.y = 20 * scale;
         }
      }
      
      private function onBackClick(event:Event) : void
      {
         this.close.dispatch();
      }
      
      private function onCharBoxOver(event:MouseEvent) : void
      {
         var charBox:CharacterBox = event.currentTarget as CharacterBox;
         charBox.setOver(true);
         this.tooltip.dispatch(charBox.getTooltip());
      }
      
      private function onCharBoxOut(event:MouseEvent) : void
      {
         var charBox:CharacterBox = event.currentTarget as CharacterBox;
         charBox.setOver(false);
         this.tooltip.dispatch(null);
      }
      
      private function onCharBoxClick(event:MouseEvent) : void
      {
         this.tooltip.dispatch(null);
         var charBox:CharacterBox = event.currentTarget.parent as CharacterBox;
         var objectType:int = charBox.objectType();
         var displayId:String = ObjectLibrary.typeToDisplayId_[objectType];
         this.selected.dispatch(objectType);
      }
      
      public function updateCreditsAndFame(credits:int, fame:int) : void
      {
         this.creditDisplay_.draw(credits,fame);
      }
   }
}
