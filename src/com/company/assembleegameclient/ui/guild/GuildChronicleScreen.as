package com.company.assembleegameclient.ui.guild
{
   import com.company.assembleegameclient.game.GameSprite;
   import com.company.assembleegameclient.game.events.GuildResultEvent;
   import com.company.assembleegameclient.objects.Player;
   import com.company.assembleegameclient.screens.TitleMenuOption;
   import com.company.assembleegameclient.ui.dialogs.Dialog;
   import com.company.assembleegameclient.ui.layout.LayoutHelper;
   import com.company.assembleegameclient.ui.layout.MenuFrame;
   import com.company.assembleegameclient.ui.layout.ScaledScreen;
   import flash.display.Graphics;
   import flash.display.Shape;
   import flash.events.Event;
   import flash.events.KeyboardEvent;
   import flash.events.MouseEvent;

   public class GuildChronicleScreen extends ScaledScreen
   {
       
      
      private var gs_:GameSprite;

      private var backdrop_:Shape;

      private var guildPlayerList_:GuildPlayerList;

      private var continueButton_:TitleMenuOption;

      public function GuildChronicleScreen(gs:GameSprite)
      {
         super();
         this.gs_ = gs;
         this.backdrop_ = new Shape();
         setBackground(this.backdrop_);
         addFrame(new MenuFrame());
         this.addList();
         this.continueButton_ = new TitleMenuOption("continue",36,false);
         this.continueButton_.addEventListener(MouseEvent.CLICK,this.onContinueClick);
         this.content.addChild(this.continueButton_);
         addEventListener(Event.ADDED_TO_STAGE,this.onAddedToStage);
         addEventListener(Event.REMOVED_FROM_STAGE,this.onRemovedFromStage);
      }

      private function addList() : void
      {
         var player:Player = this.gs_.map.player_;
         this.guildPlayerList_ = new GuildPlayerList(50,0,player == null?"":player.name_,player.guildRank_);
         this.guildPlayerList_.addEventListener(GuildPlayerListEvent.SET_RANK,this.onSetRank);
         this.guildPlayerList_.addEventListener(GuildPlayerListEvent.REMOVE_MEMBER,this.onRemoveMember);
         this.content.addChild(this.guildPlayerList_);
      }

      private function removeList() : void
      {
         this.guildPlayerList_.removeEventListener(GuildPlayerListEvent.SET_RANK,this.onSetRank);
         this.guildPlayerList_.removeEventListener(GuildPlayerListEvent.REMOVE_MEMBER,this.onRemoveMember);
         this.content.removeChild(this.guildPlayerList_);
      }

      override protected function layoutChrome(stageWidth:Number, stageHeight:Number, scale:Number) : void
      {
         var g:Graphics = this.backdrop_.graphics;
         g.clear();
         g.beginFill(2829099,0.8);
         g.drawRect(0,0,stageWidth,stageHeight);
         g.endFill();
      }
      
      private function onSetRank(event:GuildPlayerListEvent) : void
      {
         this.removeList();
         this.gs_.addEventListener(GuildResultEvent.EVENT,this.onSetRankResult);
         this.gs_.gsc_.changeGuildRank(event.name_,event.rank_);
      }
      
      private function onSetRankResult(event:GuildResultEvent) : void
      {
         this.gs_.removeEventListener(GuildResultEvent.EVENT,this.onSetRankResult);
         if(!event.success_)
         {
            this.showError(event.errorText_);
         }
         else
         {
            this.addList();
         }
      }
      
      private function onRemoveMember(event:GuildPlayerListEvent) : void
      {
         this.removeList();
         this.gs_.addEventListener(GuildResultEvent.EVENT,this.onRemoveResult);
         this.gs_.gsc_.guildRemove(event.name_);
      }
      
      private function onRemoveResult(event:GuildResultEvent) : void
      {
         this.gs_.removeEventListener(GuildResultEvent.EVENT,this.onRemoveResult);
         if(!event.success_)
         {
            this.showError(event.errorText_);
         }
         else
         {
            this.addList();
         }
      }
      
      private function showError(errorText:String) : void
      {
         var dialog:Dialog = new Dialog(errorText,"Error","Ok",null);
         dialog.addEventListener(Dialog.BUTTON1_EVENT,this.onErrorTextDone);
         stage.addChild(dialog);
      }
      
      private function onErrorTextDone(event:Event) : void
      {
         var dialog:Dialog = event.currentTarget as Dialog;
         stage.removeChild(dialog);
         this.addList();
      }
      
      private function onContinueClick(event:MouseEvent) : void
      {
         this.close();
      }
      
      private function onAddedToStage(event:Event) : void
      {
         this.continueButton_.x = LayoutHelper.centerX(this.continueButton_.width);
         this.continueButton_.y = 520;
         stage.addEventListener(KeyboardEvent.KEY_DOWN,this.onKeyDown,false,1);
         stage.addEventListener(KeyboardEvent.KEY_UP,this.onKeyUp,false,1);
         this.layout();
      }
      
      private function onRemovedFromStage(event:Event) : void
      {
         stage.removeEventListener(KeyboardEvent.KEY_DOWN,this.onKeyDown,false);
         stage.removeEventListener(KeyboardEvent.KEY_UP,this.onKeyUp,false);
      }
      
      private function onKeyDown(event:KeyboardEvent) : void
      {
         event.stopImmediatePropagation();
      }
      
      private function onKeyUp(event:KeyboardEvent) : void
      {
         event.stopImmediatePropagation();
      }
      
      private function close() : void
      {
         stage.focus = null;
         parent.removeChild(this);
      }
   }
}
