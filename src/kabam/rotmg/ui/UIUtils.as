package kabam.rotmg.ui
{
   import flash.display.Sprite;
import flash.display.StageQuality;

public class UIUtils
   {
      
      private static const NOTIFICATION_BACKGROUND_WIDTH:Number = 95;
      
      private static const NOTIFICATION_BACKGROUND_HEIGHT:Number = 25;
      
      private static const NOTIFICATION_BACKGROUND_ALPHA:Number = 0.4;
      
      private static const NOTIFICATION_BACKGROUND_COLOR:Number = 0;
      
      public static const NOTIFICATION_SPACE:uint = 28;
       
      
      public function UIUtils()
      {
         super();
      }
      
      public static function returnHudNotificationBackground() : Sprite
      {
         var background:Sprite = new Sprite();
         background.graphics.beginFill(NOTIFICATION_BACKGROUND_COLOR,NOTIFICATION_BACKGROUND_ALPHA);
         background.graphics.drawRoundRect(0,0,NOTIFICATION_BACKGROUND_WIDTH,NOTIFICATION_BACKGROUND_HEIGHT,12,12);
         background.graphics.endFill();
         return background;
      }

      public static function toggleQuality(hq:Boolean) : void
      {
         if (WebMain.STAGE != null) {
            WebMain.STAGE.quality = hq ? StageQuality.HIGH : StageQuality.LOW;
         }
      }

      public static function applyVSync(vsync:Boolean) : void
      {
         if (WebMain.STAGE != null) {
            try {
               WebMain.STAGE.vsyncEnabled = vsync;
            } catch (e:Error) {
            }
         }
      }

      private static const MAX_FPS_DEFAULT:Number = 60;
      private static const MAX_FPS_UNCAPPED:Number = 1000;

      public static function applyMaxFPS(value:*) : void
      {
         var fps:Number = Number(value);
         if (value === null || value === undefined || isNaN(fps)) {
            fps = MAX_FPS_DEFAULT;
         }
         if (WebMain.STAGE != null) {
            try {
               WebMain.STAGE.frameRate = fps <= 0 ? MAX_FPS_UNCAPPED : Math.min(Math.max(fps,1),MAX_FPS_UNCAPPED);
            } catch (e:Error) {
            }
         }
      }
   }
}
