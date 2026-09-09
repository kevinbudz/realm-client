package com.company.assembleegameclient.ui.layout
{
   import com.company.assembleegameclient.ui.SoundIcon;
   import flash.display.Graphics;
   import flash.display.Shape;
   import flash.display.Sprite;
   import flash.display.Stage;
   import flash.events.Event;
   import kabam.rotmg.ui.view.components.MapBackground;

   /**
    * Full-window responsive backdrop for menu screens.
    *
    * <p>Layers the scrolling MapBackground under a dim overlay, with
    * the sound icon scaled by the window height like the rest of the
    * UI. Add it with ScaledScreen.setBackground() so it stays
    * unscaled behind the menu content and redraws itself on every
    * stage resize.</p>
    */
   public class MenuBackground extends Sprite
   {
      private static const DIM_COLOR:uint = 0x2B2B2B;

      private static const DIM_ALPHA:Number = 0.8;

      private var dim:Shape;

      private var soundIcon:SoundIcon;

      private var stageRef:Stage;

      public function MenuBackground()
      {
         super();
         addChild(new MapBackground());
         this.dim = new Shape();
         addChild(this.dim);
         this.soundIcon = new SoundIcon();
         addChild(this.soundIcon);
         addEventListener(Event.ADDED_TO_STAGE, this.onAddedToStage);
         addEventListener(Event.REMOVED_FROM_STAGE, this.onRemovedFromStage);
         this.redraw(LayoutHelper.DESIGN_WIDTH, LayoutHelper.DESIGN_HEIGHT);
      }

      private function onAddedToStage(event:Event) : void
      {
         this.stageRef = stage;
         this.stageRef.addEventListener(Event.RESIZE, this.onStageResize);
         this.redraw(this.stageRef.stageWidth, this.stageRef.stageHeight);
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
         this.redraw(this.stageRef.stageWidth, this.stageRef.stageHeight);
      }

      private function redraw(stageWidth:Number, stageHeight:Number) : void
      {
         var g:Graphics = this.dim.graphics;
         g.clear();
         g.beginFill(DIM_COLOR, DIM_ALPHA);
         g.drawRect(0, 0, stageWidth, stageHeight);
         g.endFill();
         var scale:Number = LayoutHelper.scaleForHeight(stageHeight);
         this.soundIcon.scaleX = scale;
         this.soundIcon.scaleY = scale;
         this.soundIcon.x = 0;
         this.soundIcon.y = 0;
      }
   }
}
