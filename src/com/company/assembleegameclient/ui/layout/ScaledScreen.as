package com.company.assembleegameclient.ui.layout
{
   import flash.display.DisplayObject;
   import flash.display.Sprite;
   import flash.display.Stage;
   import flash.events.Event;

   /**
    * Base class for full-window menu screens.
    *
    * <p>Owns a design-space container (<code>content</code>) that is
    * uniformly scaled by the window height and centered on every
    * stage resize. Add centered menu elements to <code>content</code>
    * using 800x600 design coordinates.</p>
    *
    * <p>Elements bound to the real window instead (corner-anchored
    * displays, full-width lines) belong in the unscaled
    * <code>chrome</code> layer: position them in stage pixels with
    * sizes multiplied by the layout scale in
    * <code>layoutChrome()</code>. Full-window backdrops go behind
    * the content via <code>setBackground()</code> and full-width
    * frames via <code>addFrame()</code>.</p>
    */
   public class ScaledScreen extends Sprite
   {

      /** Design-space container, scaled by window height and centered. */
      protected var content:Sprite;

      /** Unscaled full-window layer above the content for window-bound chrome. */
      protected var chrome:Sprite;

      private var stageRef:Stage;

      public function ScaledScreen()
      {
         super();
         this.content = new Sprite();
         addChild(this.content);
         this.chrome = new Sprite();
         addChild(this.chrome);
         addEventListener(Event.ADDED_TO_STAGE, this.onAddedToStage);
         addEventListener(Event.REMOVED_FROM_STAGE, this.onRemovedFromStage);
      }

      /** Current height-based UI scale. Matches WebMain.uiScale(). */
      protected function get uiScale() : Number
      {
         var stageHeight:Number = this.stageRef != null ? this.stageRef.stageHeight : LayoutHelper.DESIGN_HEIGHT;
         return LayoutHelper.scaleForHeight(stageHeight);
      }

      /**
       * Adds a full-window backdrop behind the scaled content.
       * Use for MenuBackground; menu elements belong in content.
       */
      protected function setBackground(child:DisplayObject) : DisplayObject
      {
         addChildAt(child, 0);
         return child;
      }

      /**
       * Adds a full-window frame between the backdrop and the scaled
       * content. Use for MenuFrame so it spans the window width while
       * staying behind the menu elements.
       */
      protected function addFrame(child:DisplayObject) : DisplayObject
      {
         addChildAt(child, getChildIndex(this.content));
         return child;
      }

      private function onAddedToStage(event:Event) : void
      {
         this.stageRef = stage;
         this.stageRef.addEventListener(Event.RESIZE, this.onStageResize);
         this.layout();
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
         this.layout();
      }

      /**
       * Scales and centers the content for the current window size,
       * then lays out the window-bound chrome.
       */
      protected function layout() : void
      {
         var stageWidth:Number = this.stageRef != null ? Number(this.stageRef.stageWidth) : LayoutHelper.DESIGN_WIDTH;
         var stageHeight:Number = this.stageRef != null ? Number(this.stageRef.stageHeight) : LayoutHelper.DESIGN_HEIGHT;
         var scale:Number = LayoutHelper.scaleForHeight(stageHeight);
         this.content.scaleX = scale;
         this.content.scaleY = scale;
         this.content.x = LayoutHelper.contentX(stageWidth, scale);
         this.content.y = LayoutHelper.contentY(stageHeight, scale);
         this.layoutChrome(stageWidth, stageHeight, scale);
      }

      /**
       * Positions the unscaled chrome layer for the current window
       * size. Scale chrome children by <code>scale</code> and position
       * them in stage pixels: left-anchored from 0, right-anchored
       * from <code>stageWidth</code>, full-width elements from 0 to
       * <code>stageWidth</code>.
       */
      protected function layoutChrome(stageWidth:Number, stageHeight:Number, scale:Number) : void
      {
      }
   }
}
