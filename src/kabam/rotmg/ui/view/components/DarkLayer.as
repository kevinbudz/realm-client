package kabam.rotmg.ui.view.components {
import flash.display.Shape;
import flash.events.Event;

public class DarkLayer extends Shape {

    public function DarkLayer() {
        addEventListener(Event.ADDED_TO_STAGE, this.onAddedToStage);
        addEventListener(Event.REMOVED_FROM_STAGE, this.onRemovedFromStage);
        this.redraw();
    }

    private function onAddedToStage(event:Event) : void {
        stage.addEventListener(Event.RESIZE, this.onResize);
        this.redraw();
    }

    private function onRemovedFromStage(event:Event) : void {
        stage.removeEventListener(Event.RESIZE, this.onResize);
    }

    private function onResize(event:Event) : void {
        this.redraw();
    }

    private function redraw() : void {
        graphics.clear();
        graphics.beginFill(0x2B2B2B, 0.8);
        graphics.drawRect(0, 0, WebMain.sWidth, WebMain.sHeight);
        graphics.endFill();
    }

}
}
