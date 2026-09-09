package kabam.rotmg.dialogs.view
{
   import flash.display.DisplayObjectContainer;
   import flash.display.Graphics;
   import flash.display.Shape;
   import flash.display.Sprite;
   import flash.display.Stage;
   import flash.events.Event;

   public class DialogsView extends Sprite
   {


      private var background:Shape;

      private var container:DisplayObjectContainer;

      private var current:Sprite;

      private var backgroundColor:int = 1381653;

      private var stageRef:Stage;

      public function DialogsView()
      {
         super();
         addChild(this.background = new Shape());
         addChild(this.container = new Sprite());
         this.background.visible = false;
         addEventListener(Event.ADDED_TO_STAGE, this.onAddedToStage);
         addEventListener(Event.REMOVED_FROM_STAGE, this.onRemovedFromStage);
      }

      public function showBackground(color:int = 1381653) : void
      {
         this.backgroundColor = color;
         this.redrawBackground();
         this.background.visible = true;
      }

      private function onAddedToStage(event:Event) : void
      {
         this.stageRef = stage;
         this.stageRef.addEventListener(Event.RESIZE, this.onStageResize);
         if (this.background.visible)
         {
            this.redrawBackground();
         }
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
         if (this.background.visible)
         {
            this.redrawBackground();
         }
      }

      private function redrawBackground() : void
      {
         var stageWidth:Number = WebMain.sWidth;
         var stageHeight:Number = WebMain.sHeight;
         if (this.stageRef != null)
         {
            stageWidth = this.stageRef.stageWidth;
            stageHeight = this.stageRef.stageHeight;
         }
         var g:Graphics = this.background.graphics;
         g.clear();
         g.beginFill(this.backgroundColor, 0.6);
         g.drawRect(0, 0, stageWidth, stageHeight);
         g.endFill();
      }

      public function show(dialog:Sprite) : void
      {
         this.removeCurrentDialog();
         this.addDialog(dialog);
      }

      public function hideAll() : void
      {
         this.background.visible = false;
         this.removeCurrentDialog();
      }

      private function addDialog(dialog:Sprite) : void
      {
         this.current = dialog;
         dialog.addEventListener(Event.REMOVED,this.onRemoved);
         this.container.addChild(dialog);
         this.showBackground();
      }

      private function onRemoved(event:Event) : void
      {
         var target:Sprite = event.target as Sprite;
         if(this.current == target)
         {
            this.background.visible = false;
            this.current = null;
         }
      }

      private function removeCurrentDialog() : void
      {
         if(this.current && this.container.contains(this.current))
         {
            this.current.removeEventListener(Event.REMOVED,this.onRemoved);
            this.container.removeChild(this.current);
            this.background.visible = false;
         }
      }
   }
}
