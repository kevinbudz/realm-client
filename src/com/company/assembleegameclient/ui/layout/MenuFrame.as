package com.company.assembleegameclient.ui.layout
{
   import flash.display.GradientType;
   import flash.display.Shape;
   import flash.display.Sprite;
   import flash.display.Stage;
   import flash.events.Event;
   import flash.geom.Matrix;

   /**
    * Full-window replacement for the embedded ScreenGraphic.
    *
    * <p>The original is a fixed 800px wide asset: a grey bottom
    * button bar (y 524-576) with a soft black glow band fading in
    * above it (y 508-588). This redraws the same artwork as vectors
    * spanning the full window width on every stage resize, with
    * heights scaled by the window height like the rest of the UI.
    * Add it with ScaledScreen.addFrame() so it sits behind the menu
    * elements.</p>
    */
   public class MenuFrame extends Sprite
   {

      private static const BAR_COLOR:uint = 0x545454;

      private static const BAR_TOP:Number = 524;

      private static const BAR_HEIGHT:Number = 52;

      private static const GLOW_TOP:Number = 508;

      private static const GLOW_HEIGHT:Number = 80;

      private static const GLOW_ALPHA:Number = 0.73;

      private var bar:Shape;

      private var glow:Shape;

      private var stageRef:Stage;

      public function MenuFrame()
      {
         super();
         this.glow = new Shape();
         addChild(this.glow);
         this.bar = new Shape();
         addChild(this.bar);
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
         var scale:Number = LayoutHelper.scaleForHeight(stageHeight);
         var barY:Number = BAR_TOP * scale;
         this.bar.graphics.clear();
         this.bar.graphics.beginFill(BAR_COLOR);
         this.bar.graphics.drawRect(0, barY, stageWidth, BAR_HEIGHT * scale);
         this.bar.graphics.endFill();
         var glowY:Number = GLOW_TOP * scale;
         var glowH:Number = GLOW_HEIGHT * scale;
         var matrix:Matrix = new Matrix();
         matrix.createGradientBox(stageWidth, glowH, Math.PI / 2, 0, glowY);
         this.glow.graphics.clear();
         this.glow.graphics.beginGradientFill(GradientType.LINEAR,
               [0, 0, 0, 0],[0, GLOW_ALPHA, GLOW_ALPHA, 0],[20, 103, 173, 237], matrix);
         this.glow.graphics.drawRect(0, glowY, stageWidth, glowH);
         this.glow.graphics.endFill();
      }
   }
}
