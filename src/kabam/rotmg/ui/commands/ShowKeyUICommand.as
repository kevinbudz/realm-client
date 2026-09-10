package kabam.rotmg.ui.commands
{
   import flash.display.DisplayObjectContainer;
   import kabam.rotmg.ui.view.KeysView;
   
   public class ShowKeyUICommand
   {
      
      
      [Inject]
      public var contextView:DisplayObjectContainer;
      
      public function ShowKeyUICommand()
      {
         super();
      }
      
      public function execute() : void
      {
         //The server re-sends showKeyUI on every Davy enter; do not stack
         //a second panel when one is already present.
         for(var i:int = 0; i < this.contextView.numChildren; i++)
         {
            if(this.contextView.getChildAt(i) is KeysView)
            {
               return;
            }
         }
         var view:KeysView = new KeysView();
         view.x = 4;
         view.y = 4;
         this.contextView.addChild(view);
      }
   }
}
