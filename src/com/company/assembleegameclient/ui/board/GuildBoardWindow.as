package com.company.assembleegameclient.ui.board
{
   import com.company.assembleegameclient.ui.dialogs.Dialog;
   import com.company.assembleegameclient.ui.layout.ScaledScreen;
   import com.company.util.MoreObjectUtil;
   import flash.display.Graphics;
   import flash.display.Shape;
   import flash.events.Event;
   import kabam.rotmg.account.core.Account;
   import kabam.rotmg.appengine.api.AppEngineClient;
   import kabam.rotmg.core.StaticInjectorContext;

   public class GuildBoardWindow extends ScaledScreen
   {
       
      
      private var canEdit_:Boolean;
      
      private var darkBox_:Shape;
      
      private var dialog_:Dialog;
      
      private var text_:String;
      
      private var viewBoard_:ViewBoard;
      
      private var editBoard_:EditBoard;
      
      private var client:AppEngineClient;
      
      public function GuildBoardWindow(canEdit:Boolean)
      {
         super();
         this.canEdit_ = canEdit;
         this.darkBox_ = new Shape();
         setBackground(this.darkBox_);
         this.load();
      }

      override protected function layoutChrome(stageWidth:Number, stageHeight:Number, scale:Number) : void
      {
         var g:Graphics = this.darkBox_.graphics;
         g.clear();
         g.beginFill(0,0.8);
         g.drawRect(0,0,stageWidth,stageHeight);
         g.endFill();
      }
      
      private function load() : void
      {
         var account:Account = StaticInjectorContext.getInjector().getInstance(Account);
         this.client = StaticInjectorContext.getInjector().getInstance(AppEngineClient);
         this.client.complete.addOnce(this.onGetBoardComplete);
         this.client.sendRequest("/guild/getBoard",account.getCredentials());
         this.dialog_ = new Dialog("Loading...",null,null,null);
         this.chrome.addChild(this.dialog_);
         this.darkBox_.visible = false;
      }
      
      private function onGetBoardComplete(isOK:Boolean, data:*) : void
      {
         if(isOK)
         {
            this.showGuildBoard(data);
         }
         else
         {
            this.reportError(data);
         }
      }
      
      private function showGuildBoard(data:String) : void
      {
         this.darkBox_.visible = true;
         this.chrome.removeChild(this.dialog_);
         this.dialog_ = null;
         this.text_ = data;
         this.show();
      }
      
      private function show() : void
      {
         this.viewBoard_ = new ViewBoard(this.text_,this.canEdit_);
         this.viewBoard_.x = 800 / 2 - this.viewBoard_.w_ / 2;
         this.viewBoard_.y = 600 / 2 - this.viewBoard_.h_ / 2;
         this.viewBoard_.addEventListener(Event.COMPLETE,this.onViewComplete);
         this.viewBoard_.addEventListener(Event.CHANGE,this.onViewChange);
         this.content.addChild(this.viewBoard_);
      }
      
      private function reportError(error:String) : void
      {
         trace("load error: " + error);
      }
      
      private function onViewComplete(event:Event) : void
      {
         parent.removeChild(this);
      }
      
      private function onViewChange(event:Event) : void
      {
         this.content.removeChild(this.viewBoard_);
         this.viewBoard_ = null;
         this.editBoard_ = new EditBoard(this.text_);
         this.editBoard_.x = 800 / 2 - this.editBoard_.w_ / 2;
         this.editBoard_.y = 600 / 2 - this.editBoard_.h_ / 2;
         this.editBoard_.addEventListener(Event.CANCEL,this.onEditCancel);
         this.editBoard_.addEventListener(Event.COMPLETE,this.onEditComplete);
         this.content.addChild(this.editBoard_);
      }

      private function onEditCancel(event:Event) : void
      {
         this.content.removeChild(this.editBoard_);
         this.editBoard_ = null;
         this.show();
      }
      
      private function onEditComplete(event:Event) : void
      {
         var account:Account = StaticInjectorContext.getInjector().getInstance(Account);
         var params:Object = {"board":this.editBoard_.getText()};
         MoreObjectUtil.addToObject(params,account.getCredentials());
         this.client = StaticInjectorContext.getInjector().getInstance(AppEngineClient);
         this.client.complete.addOnce(this.onSetBoardComplete);
         this.client.sendRequest("/guild/setBoard",params);
         this.content.removeChild(this.editBoard_);
         this.editBoard_ = null;
         this.dialog_ = new Dialog("Saving...",null,null,null);
         this.chrome.addChild(this.dialog_);
         this.darkBox_.visible = false;
      }
      
      private function onSetBoardComplete(isOK:Boolean, data:*) : void
      {
         if(isOK)
         {
            this.onSaveDone(data);
         }
         else
         {
            this.onSaveError(data);
         }
      }
      
      private function onSaveDone(data:String) : void
      {
         this.darkBox_.visible = true;
         this.chrome.removeChild(this.dialog_);
         this.dialog_ = null;
         this.text_ = data;
         this.show();
      }
      
      private function onSaveError(error:String) : void
      {
         trace("save error: " + error);
      }
   }
}
