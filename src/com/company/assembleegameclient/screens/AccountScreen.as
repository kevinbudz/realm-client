package com.company.assembleegameclient.screens
{
   import com.company.assembleegameclient.ui.GuildText;
   import com.company.assembleegameclient.ui.RankText;
   import com.company.assembleegameclient.ui.layout.LayoutHelper;
   import com.company.assembleegameclient.ui.tooltip.RankToolTip;
   import flash.display.DisplayObject;
   import flash.display.Sprite;
   import flash.display.Stage;
   import flash.events.Event;
   import flash.events.MouseEvent;
   import kabam.rotmg.account.core.view.AccountInfoView;
   import org.osflash.signals.Signal;

   /**
    * Menu header: star rank top-left beside the sound icon, guild
    * name next to it, account info top-right.
    *
    * <p>Must live in an unscaled full-window parent (ScaledScreen
    * chrome): it scales itself by the window height and anchors to
    * the real window corners on every stage resize, so the header
    * stays glued to the window edges at any resolution.</p>
    */
   public class AccountScreen extends Sprite
   {

      private static const RANK_X:Number = 36;

      private static const RANK_Y:Number = 4;

      private static const GUILD_X:Number = 92;

      private static const GUILD_Y:Number = 6;

      private static const INFO_MARGIN:Number = 10;

      private static const INFO_Y:Number = 2;

      public var tooltip:Signal;

      private var guildName:String;

      private var guildRank:int;

      private var stars:int;

      private var rankText:RankText;

      private var guildText:GuildText;

      private var accountInfo:AccountInfoView;

      private var stageRef:Stage;

      public function AccountScreen()
      {
         super();
         this.tooltip = new Signal();
         addEventListener(Event.ADDED_TO_STAGE, this.onAddedToStage);
         addEventListener(Event.REMOVED_FROM_STAGE, this.onRemovedFromStage);
         this.refresh();
      }

      public function setGuild(guildName:String, guildRank:int) : void
      {
         this.guildName = guildName;
         this.guildRank = guildRank;
         this.makeGuildText();
      }

      private function makeGuildText() : void
      {
         if (this.guildText != null && contains(this.guildText))
         {
            removeChild(this.guildText);
         }
         this.guildText = new GuildText(this.guildName,this.guildRank);
         addChild(this.guildText);
         this.refresh();
      }

      public function setRank(stars:int) : void
      {
         this.stars = stars;
         this.makeRankText();
      }

      private function makeRankText() : void
      {
         if (this.rankText != null && contains(this.rankText))
         {
            removeChild(this.rankText);
         }
         this.rankText = new RankText(this.stars,true,false);
         this.rankText.mouseEnabled = true;
         this.rankText.addEventListener(MouseEvent.MOUSE_OVER,this.onMouseOver);
         this.rankText.addEventListener(MouseEvent.ROLL_OUT,this.onRollOut);
         addChild(this.rankText);
         this.refresh();
      }

      public function setAccountInfo(accountInfo:AccountInfoView) : void
      {
         var oldDisplay:DisplayObject = this.accountInfo as DisplayObject;
         if (oldDisplay != null && contains(oldDisplay))
         {
            removeChild(oldDisplay);
         }
         this.accountInfo = accountInfo;
         var display:DisplayObject = accountInfo as DisplayObject;
         addChild(display);
         this.refresh();
      }

      private function onAddedToStage(event:Event) : void
      {
         this.stageRef = stage;
         this.stageRef.addEventListener(Event.RESIZE, this.onStageResize);
         this.refresh();
      }

      private function onRemovedFromStage(event:Event) : void
      {
         if (this.stageRef != null)
         {
            this.stageRef.removeEventListener(Event.RESIZE, this.onStageResize);
            this.stageRef = null;
         }
      }

      private function onStageResize(event:Event) : void
      {
         this.refresh();
      }

      private function refresh() : void
      {
         var stageWidth:Number = this.stageRef != null ? Number(this.stageRef.stageWidth) : LayoutHelper.DESIGN_WIDTH;
         var stageHeight:Number = this.stageRef != null ? Number(this.stageRef.stageHeight) : LayoutHelper.DESIGN_HEIGHT;
         var scale:Number = LayoutHelper.scaleForHeight(stageHeight);
         if (this.rankText != null)
         {
            this.rankText.scaleX = scale;
            this.rankText.scaleY = scale;
            this.rankText.x = RANK_X * scale;
            this.rankText.y = RANK_Y * scale;
         }
         if (this.guildText != null)
         {
            this.guildText.scaleX = scale;
            this.guildText.scaleY = scale;
            this.guildText.x = GUILD_X * scale;
            this.guildText.y = GUILD_Y * scale;
         }
         if (this.accountInfo != null)
         {
            var display:DisplayObject = this.accountInfo as DisplayObject;
            display.scaleX = scale;
            display.scaleY = scale;
            display.x = stageWidth - INFO_MARGIN;
            display.y = INFO_Y * scale;
         }
      }

      protected function onMouseOver(event:MouseEvent) : void
      {
         this.tooltip.dispatch(new RankToolTip(this.stars));
      }

      protected function onRollOut(event:MouseEvent) : void
      {
         this.tooltip.dispatch(null);
      }
   }
}
