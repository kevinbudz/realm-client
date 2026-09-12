package com.company.assembleegameclient.util
{
   import com.company.assembleegameclient.parameters.Parameters;
   import com.company.ui.SimpleText;
   import flash.display.Sprite;
   import flash.events.Event;
   import flash.filters.DropShadowFilter;

   /**
    * On-screen readout for FrameProfiler. Enables the profiler while on stage and disables it
    * when removed, so there's zero cost when the overlay is hidden.
    */
   public class FrameProfilerView extends Sprite
   {
      private var text_:SimpleText;
      private var lastSerial_:int = -1;

      public function FrameProfilerView()
      {
         super();
         this.text_ = new SimpleText(12,16777215,false,0,0);
         this.text_.filters = [new DropShadowFilter(0,0,0)];
         addChild(this.text_);
         addEventListener(Event.ADDED_TO_STAGE,this.onAddedToStage);
         addEventListener(Event.REMOVED_FROM_STAGE,this.onRemovedFromStage);
      }

      private function onAddedToStage(event:Event) : void
      {
         FrameProfiler.reset();
         FrameProfiler.enabled = true;
         this.lastSerial_ = -1;
         this.text_.text = "profiling...";
         this.text_.useTextDimensions();
         stage.addEventListener(Event.ENTER_FRAME,this.onEnterFrame);
      }

      private function onRemovedFromStage(event:Event) : void
      {
         stage.removeEventListener(Event.ENTER_FRAME,this.onEnterFrame);
         FrameProfiler.enabled = false;
      }

      private function onEnterFrame(event:Event) : void
      {
         if(FrameProfiler.reportSerial == this.lastSerial_)
         {
            return;
         }
         this.lastSerial_ = FrameProfiler.reportSerial;
         var s:String = (Parameters.GPURenderFrame ? "gpu" : "software") + "  " + FrameProfiler.reportedFrames + " fps";
         s += "  vsync " + (Parameters.data_.vsync !== false ? "on" : "off") + "  cap " + (Number(Parameters.data_.maxFPS) > 0 ? String(Parameters.data_.maxFPS) : "none") + "\n";
         s += "frame   " + fmt(FrameProfiler.avgFrame) + "\n";
         s += "script  " + fmt(FrameProfiler.avgScript) + "\n";
         s += "render+idle " + fmt(FrameProfiler.avgRender) + "\n";
         for(var i:int = 0; i < FrameProfiler.SECTION_COUNT; i++)
         {
            s += "  " + pad(FrameProfiler.SECTION_NAMES[i], 11) + fmt(FrameProfiler.avgSection[i]) + "\n";
         }
         s += "objs " + int(FrameProfiler.avgObjects) + "  tiles " + int(FrameProfiler.avgTiles) + "  gfx " + int(FrameProfiler.avgGraphicsData) + "  drawCalls " + int(FrameProfiler.avgDrawCalls);
         if(Parameters.GPURenderFrame && FrameProfiler.atlasInfo.length > 0)
         {
            s += "\n" + FrameProfiler.atlasInfo;
         }
         this.text_.text = s;
         this.text_.useTextDimensions();
      }

      private static function fmt(ms:Number) : String
      {
         return (Math.round(ms * 100) / 100).toFixed(2) + " ms";
      }

      private static function pad(s:String, n:int) : String
      {
         while(s.length < n)
         {
            s += " ";
         }
         return s;
      }
   }
}
