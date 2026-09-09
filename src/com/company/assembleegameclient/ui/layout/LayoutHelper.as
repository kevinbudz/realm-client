package com.company.assembleegameclient.ui.layout
{

   /**
    * Static math for the menu layout system.
    *
    * <p>Every menu screen is authored in a fixed design space of
    * 800x600 and uniformly scaled by the window height at runtime
    * (scale = stageHeight / 600), exactly like the in-game HUD
    * (see WebMain.uiScale() and GameSprite.onScreenResize()).
    * The scaled content is then centered, so menus stay coherent
    * at any window size or aspect ratio.</p>
    *
    * <p>Author all positions and sizes in design units and let
    * ScaledScreen apply the scale. Never read stage.stageWidth or
    * stage.stageHeight for layout; use the design constants and
    * the helpers below instead.</p>
    */
   public final class LayoutHelper
   {

      /** Width of the design space every menu screen is authored in. */
      public static const DESIGN_WIDTH:Number = 800;

      /** Height of the design space every menu screen is authored in. */
      public static const DESIGN_HEIGHT:Number = 600;


      /**
       * Height-based UI scale for a window of the given height.
       * Matches WebMain.uiScale().
       */
      public static function scaleForHeight(stageHeight:Number) : Number
      {
         if (stageHeight <= 0)
         {
            return 1;
         }
         return stageHeight / DESIGN_HEIGHT;
      }

      /** Horizontal offset that centers scaled design content in the window. */
      public static function contentX(stageWidth:Number, scale:Number) : Number
      {
         return (stageWidth - DESIGN_WIDTH * scale) / 2;
      }

      /** Vertical offset that centers scaled design content in the window. */
      public static function contentY(stageHeight:Number, scale:Number) : Number
      {
         return (stageHeight - DESIGN_HEIGHT * scale) / 2;
      }

      /** X that centers an object of the given width in design space. */
      public static function centerX(objectWidth:Number, areaWidth:Number = DESIGN_WIDTH) : Number
      {
         return (areaWidth - objectWidth) / 2;
      }

      /** Y that centers an object of the given height in design space. */
      public static function centerY(objectHeight:Number, areaHeight:Number = DESIGN_HEIGHT) : Number
      {
         return (areaHeight - objectHeight) / 2;
      }

      /** X that right-aligns an object of the given width in design space. */
      public static function rightX(objectWidth:Number, margin:Number = 0, areaWidth:Number = DESIGN_WIDTH) : Number
      {
         return areaWidth - margin - objectWidth;
      }
   }
}
