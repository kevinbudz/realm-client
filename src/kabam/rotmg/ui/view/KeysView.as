package kabam.rotmg.ui.view
{
   import com.company.assembleegameclient.ui.layout.LayoutHelper;
   import flash.display.Sprite;
   import flash.display.Stage;
   import flash.events.Event;
   import kabam.rotmg.ui.model.Key;
   import mx.core.BitmapAsset;

   public class KeysView extends Sprite
   {

      private static const MARGIN:Number = 4;

      private static var keyBackgroundPng:Class = KeysView_keyBackgroundPng;

      private static var greenKeyPng:Class = KeysView_greenKeyPng;

      private static var redKeyPng:Class = KeysView_redKeyPng;

      private static var yellowKeyPng:Class = KeysView_yellowKeyPng;

      private static var purpleKeyPng:Class = KeysView_purpleKeyPng;


      private var base:BitmapAsset;

      private var keys:Vector.<BitmapAsset>;

      private var stageRef:Stage;

      public function KeysView()
      {
         super();
         this.base = new keyBackgroundPng();
         addChild(this.base);
         this.keys = new Vector.<BitmapAsset>(4,true);
         this.keys[0] = new purpleKeyPng();
         this.keys[1] = new greenKeyPng();
         this.keys[2] = new redKeyPng();
         this.keys[3] = new yellowKeyPng();
         for(var i:int = 0; i < 4; i++)
         {
            this.keys[i].x = 12 + 40 * i;
            this.keys[i].y = 12;
         }
         addEventListener(Event.ADDED_TO_STAGE, this.onAddedToStage);
         addEventListener(Event.REMOVED_FROM_STAGE, this.onRemovedFromStage);
         this.layout();
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
       * Scales the panel by the window height, like the rest of the
       * game HUD (see GameSprite.onScreenResize). The view is
       * parented to the unscaled context layer, so it must scale
       * itself and anchor to the top-left in stage pixels.
       */
      private function layout() : void
      {
         var stageHeight:Number = this.stageRef != null ? Number(this.stageRef.stageHeight) : LayoutHelper.DESIGN_HEIGHT;
         var scale:Number = LayoutHelper.scaleForHeight(stageHeight);
         this.scaleX = scale;
         this.scaleY = scale;
         this.x = MARGIN * scale;
         this.y = MARGIN * scale;
      }

      public function showKey(key:Key) : void
      {
         var asset:BitmapAsset = this.keys[key.position];
         if(!contains(asset))
         {
            addChild(asset);
         }
      }

      public function hideKey(key:Key) : void
      {
         var asset:BitmapAsset = this.keys[key.position];
         if(contains(asset))
         {
            removeChild(asset);
         }
      }
   }
}
