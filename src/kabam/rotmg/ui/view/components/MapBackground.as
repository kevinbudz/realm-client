package kabam.rotmg.ui.view.components
{
   import com.company.assembleegameclient.map.Camera;
   import com.company.assembleegameclient.map.Map;
   import com.company.assembleegameclient.map.serialization.MapDecoder;
   import com.company.assembleegameclient.ui.layout.LayoutHelper;
   import com.company.util.IntPoint;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.geom.Rectangle;
   import flash.utils.ByteArray;
   import flash.utils.getTimer;

   /**
    * Full-window scrolling map backdrop for the title screen.
    *
    * <p>Ports the reference MapBackground: an embedded background map
    * that pans slowly past a fixed-angle camera. The camera viewport
    * tracks the real window size (floored at the 800x600 design space
    * so the composition never shrinks) instead of the reference's
    * fixed 800x600 rect, so the map fills any window like the other
    * ScaledScreen backdrops. It is hosted by MenuBackground, which
    * puts all menu screens over the same scrolling map.</p>
    */
   public class MapBackground extends Sprite
   {
      private static const BORDER:int = 10;
      // Mirrors com.company.assembleegameclient.background.Background.NO_BACKGROUND.
      // A local copy is needed because this package already contains an
      // unrelated Background class that shadows that import.
      private static const NO_MAP_BACKGROUND:int = 0;
      private static const ANGLE:Number = 7 * Math.PI / 4;
      private static const TO_MILLISECONDS:Number = 1 / 1000;
      private static const EMBEDDED_BACKGROUNDMAP:Class = MapBackground_EMBEDDED_BACKGROUNDMAP;

      private static var backgroundMap:Map;
      private static var mapSize:IntPoint;
      private static var xVal:Number;
      private static var yVal:Number;
      private static var camera:Camera;

      private var viewport:Rectangle = new Rectangle(-400, -300, LayoutHelper.DESIGN_WIDTH, LayoutHelper.DESIGN_HEIGHT);
      private var lastUpdate:int;
      private var time:Number;

      public function MapBackground()
      {
         super();
         addEventListener(Event.ADDED_TO_STAGE, this.onAddedToStage);
         addEventListener(Event.REMOVED_FROM_STAGE, this.onRemovedFromStage);
      }

      private function onAddedToStage(event:Event) : void
      {
         addChildAt(backgroundMap = backgroundMap || this.makeMap(), 0);
         addEventListener(Event.ENTER_FRAME, this.onEnterFrame);
         this.lastUpdate = getTimer();
      }

      private function onRemovedFromStage(event:Event) : void
      {
         removeEventListener(Event.ENTER_FRAME, this.onEnterFrame);
      }

      private function onEnterFrame(event:Event) : void
      {
         this.time = getTimer();
         xVal = xVal + (this.time - this.lastUpdate) * TO_MILLISECONDS;
         if (xVal > mapSize.x_ + BORDER)
         {
            xVal = xVal - mapSize.x_;
         }
         this.updateViewport();
         // false selects the non-perspective path, matching the
         // reference client's five-argument Camera.configure().
         camera.configure(xVal, yVal, 12, ANGLE, this.viewport, false);
         backgroundMap.draw(camera, this.time);
         this.lastUpdate = this.time;
      }

      private function updateViewport() : void
      {
         var viewWidth:Number = LayoutHelper.DESIGN_WIDTH;
         var viewHeight:Number = LayoutHelper.DESIGN_HEIGHT;
         if (stage != null)
         {
            viewWidth = Math.max(viewWidth, stage.stageWidth);
            viewHeight = Math.max(viewHeight, stage.stageHeight);
         }
         this.viewport.x = -viewWidth / 2;
         this.viewport.y = -viewHeight / 2;
         this.viewport.width = viewWidth;
         this.viewport.height = viewHeight;
      }

      private function makeMap() : Map
      {
         var data:ByteArray = new EMBEDDED_BACKGROUNDMAP();
         var encodedMap:String = data.readUTFBytes(data.length);
         mapSize = MapDecoder.getSize(encodedMap);
         xVal = BORDER;
         yVal = BORDER + int((mapSize.y_ - 2 * BORDER) * Math.random());
         camera = new Camera();
         var map:Map = new Map(null);
         map.setProps(mapSize.x_ + 2 * BORDER, mapSize.y_, "Background Map", NO_MAP_BACKGROUND, false, false);
         map.initialize();
         MapDecoder.writeMap(encodedMap, map, 0, 0);
         MapDecoder.writeMap(encodedMap, map, mapSize.x_, 0);
         return map;
      }
   }
}
