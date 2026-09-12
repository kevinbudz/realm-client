package com.company.assembleegameclient.util
{
   import flash.utils.getTimer;

   /**
    * Lightweight per-frame section timer. getTimer() is millisecond resolution, so single-frame
    * numbers are noisy; values are accumulated and averaged over REPORT_INTERVAL_MS windows.
    *
    * Usage: FrameProfiler.frameStart() at the top of the game loop, frameEnd() at the bottom,
    * and begin(SECTION)/end(SECTION) around code of interest. Everything is a no-op while
    * `enabled` is false, so the calls can stay in the hot path.
    */
   public class FrameProfiler
   {
      public static const UPDATE:int = 0;
      public static const TILES:int = 1;
      public static const COLLECT:int = 2;
      public static const SORT:int = 3;
      public static const DRAW_UNDER:int = 4;
      public static const SHADOWS:int = 5;
      public static const DRAW_OBJECTS:int = 6;
      public static const TOP_TILES:int = 7;
      public static const PRESENT:int = 8;
      public static const OVERLAYS:int = 9;
      public static const HUD:int = 10;
      // Sub-sections of PRESENT in GPU mode.
      public static const GPU_SCENE:int = 11;     // renderScene: per-quad Context3D calls
      public static const GPU_SWAP:int = 12;      // Context3D.present(): may block on GPU/vsync
      public static const GPU_SOFTWARE:int = 13;  // software-fill fallback pass
      public static const SECTION_COUNT:int = 14;

      public static const SECTION_NAMES:Vector.<String> = new <String>[
         "update", "tiles", "collect", "sort", "drawUnder", "shadows",
         "drawObjs", "topTiles", "present", "overlays", "hud",
         " gpuScene", " gpuSwap", " gpuSoft"];

      private static const REPORT_INTERVAL_MS:int = 1000;

      public static var enabled:Boolean = false;

      // Last completed report, in average ms per frame.
      public static var avgSection:Vector.<Number> = new Vector.<Number>(SECTION_COUNT, true);
      public static var avgScript:Number = 0;   // time inside onEnterFrame
      public static var avgRender:Number = 0;   // frame interval minus script (display-list render + idle/vsync)
      public static var avgFrame:Number = 0;    // interval between frameStart calls
      public static var avgObjects:Number = 0;
      public static var avgTiles:Number = 0;
      public static var avgGraphicsData:Number = 0;
      public static var avgDrawCalls:Number = 0;
      public static var reportedFrames:int = 0;
      public static var reportSerial:int = 0;

      private static var accSection:Vector.<Number> = new Vector.<Number>(SECTION_COUNT, true);
      private static var startSection:Vector.<int> = new Vector.<int>(SECTION_COUNT, true);
      private static var accScript:int = 0;
      private static var accFrame:int = 0;
      private static var accObjects:int = 0;
      private static var accTiles:int = 0;
      private static var accGraphicsData:int = 0;
      private static var accDrawCalls:int = 0;
      private static var frames:int = 0;
      private static var frameStartTime:int = 0;
      private static var lastFrameStartTime:int = 0;
      private static var windowStartTime:int = 0;

      // Per-frame counts, set by the map each frame.
      public static var frameObjects:int = 0;
      public static var frameTiles:int = 0;
      public static var frameGraphicsData:int = 0;
      public static var frameDrawCalls:int = 0;  // always incremented; cheap, and reset here each frame

      public static function frameStart() : void
      {
         frameDrawCalls = 0;
         if(!enabled)
         {
            return;
         }
         var now:int = getTimer();
         if(lastFrameStartTime != 0)
         {
            accFrame += now - lastFrameStartTime;
         }
         else
         {
            windowStartTime = now;
         }
         lastFrameStartTime = now;
         frameStartTime = now;
      }

      public static function frameEnd() : void
      {
         if(!enabled || frameStartTime == 0)
         {
            return;
         }
         var now:int = getTimer();
         accScript += now - frameStartTime;
         accObjects += frameObjects;
         accTiles += frameTiles;
         accGraphicsData += frameGraphicsData;
         accDrawCalls += frameDrawCalls;
         frames++;
         if(now - windowStartTime >= REPORT_INTERVAL_MS)
         {
            report();
            windowStartTime = now;
         }
      }

      public static function begin(section:int) : void
      {
         if(enabled)
         {
            startSection[section] = getTimer();
         }
      }

      public static function end(section:int) : void
      {
         if(enabled)
         {
            accSection[section] += getTimer() - startSection[section];
         }
      }

      public static function reset() : void
      {
         for(var i:int = 0; i < SECTION_COUNT; i++)
         {
            accSection[i] = 0;
            avgSection[i] = 0;
         }
         accScript = accFrame = accObjects = accTiles = accGraphicsData = accDrawCalls = 0;
         frames = 0;
         frameStartTime = lastFrameStartTime = windowStartTime = 0;
         avgScript = avgRender = avgFrame = avgObjects = avgTiles = avgGraphicsData = avgDrawCalls = 0;
         reportedFrames = 0;
      }

      private static function report() : void
      {
         if(frames <= 0)
         {
            return;
         }
         var inv:Number = 1 / frames;
         for(var i:int = 0; i < SECTION_COUNT; i++)
         {
            avgSection[i] = accSection[i] * inv;
            accSection[i] = 0;
         }
         avgScript = accScript * inv;
         avgFrame = accFrame * inv;
         avgRender = Math.max(0, avgFrame - avgScript);
         avgObjects = accObjects * inv;
         avgTiles = accTiles * inv;
         avgGraphicsData = accGraphicsData * inv;
         avgDrawCalls = accDrawCalls * inv;
         reportedFrames = frames;
         reportSerial++;
         accScript = accFrame = accObjects = accTiles = accGraphicsData = accDrawCalls = 0;
         frames = 0;
      }
   }
}
