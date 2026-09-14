package com.company.assembleegameclient.map
{
   import com.company.assembleegameclient.parameters.Parameters;
   import com.company.assembleegameclient.util.FrameProfiler;
   import flash.display.IGraphicsData;
   import flash.display.Sprite;
   import kabam.rotmg.core.StaticInjectorContext;
   import kabam.rotmg.stage3D.GraphicsFillExtra;
   import kabam.rotmg.stage3D.Object3D.Object3DStage3D;
   import kabam.rotmg.stage3D.Render3D;
   import kabam.rotmg.stage3D.Renderer;

   // Sole present path for Map.draw (GPU frames): dispatches the batched
   // scene and runs extras maintenance under the same profiler sections the
   // inline fork used to own. The software-triple blit is gone: every
   // producer has a GPU twin, so no software triples can exist (see
   // batchGraphicsItem), and the mode-switch clear in Map.draw covers
   // transitions — steady-state GPU frames clear nothing.
   public class MapRenderer
   {
      private var map_:Sprite;

      public function MapRenderer(map:Sprite)
      {
         super();
         this.map_ = map;
      }

      public function present(graphicsData:Vector.<IGraphicsData>, graphicsData3d:Vector.<Object3DStage3D>, mapWidth:int, mapHeight:int, camera:Camera, filter:uint, time:int) : void
      {
         if(Parameters.isGpuRender() && Renderer.inGame)
         {
            FrameProfiler.begin(FrameProfiler.GPU_DISPATCH);
            StaticInjectorContext.getInjector().getInstance(Render3D).dispatch(graphicsData,graphicsData3d,mapWidth,mapHeight,camera,filter);
            FrameProfiler.end(FrameProfiler.GPU_DISPATCH);
            if(time % 149 == 0)
            {
               GraphicsFillExtra.manageSize();
            }
         }
         else
         {
            this.map_.graphics.clear();
            this.map_.graphics.drawGraphicsData(graphicsData);
         }
      }
   }
}
