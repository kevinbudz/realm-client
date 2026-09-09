package com.company.assembleegameclient.ui
{
   import com.company.assembleegameclient.account.ui.Frame;
   import flash.display.Graphics;
   import flash.display.Shape;
   import flash.display.Sprite;
   import flash.display.Stage;
   import flash.events.Event;

   public class FrameOverlay extends Sprite
   {


      private var darkBox_:Shape;

      private var frame_:Frame;

      private var stageRef:Stage;

      public function FrameOverlay(frame:Frame)
      {
         super();
         this.darkBox_ = new Shape();
         addChild(this.darkBox_);
         this.frame_ = frame;
         this.frame_.addEventListener(Event.COMPLETE,this.onFrameDone);
         addChild(this.frame_);
         this.redraw();
         addEventListener(Event.ADDED_TO_STAGE, this.onAddedToStage);
         addEventListener(Event.REMOVED_FROM_STAGE, this.onRemovedFromStage);
      }

      private function onAddedToStage(event:Event) : void
      {
         this.stageRef = stage;
         this.stageRef.addEventListener(Event.RESIZE, this.onStageResize);
         this.redraw();
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
         this.redraw();
      }

      private function redraw() : void
      {
         var stageWidth:Number = WebMain.sWidth;
         var stageHeight:Number = WebMain.sHeight;
         if (this.stageRef != null)
         {
            stageWidth = this.stageRef.stageWidth;
            stageHeight = this.stageRef.stageHeight;
         }
         var g:Graphics = this.darkBox_.graphics;
         g.clear();
         g.beginFill(0,0.8);
         g.drawRect(0,0,stageWidth,stageHeight);
         g.endFill();
      }

      private function onFrameDone(event:Event) : void
      {
         parent.removeChild(this);
      }
   }
}
