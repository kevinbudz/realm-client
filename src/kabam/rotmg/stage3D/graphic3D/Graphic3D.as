package kabam.rotmg.stage3D.graphic3D
{
   import com.company.assembleegameclient.util.FrameProfiler;
   import flash.display.BitmapData;
   import flash.display.GraphicsBitmapFill;
   import flash.display.GraphicsGradientFill;
   import flash.display.GraphicsPath;
   import flash.display.IGraphicsData;
   import flash.display3D.Context3D;
   import flash.display3D.Context3DBufferUsage;
   import flash.display3D.Context3DProgramType;
   import flash.display3D.Context3DVertexBufferFormat;
   import flash.display3D.IndexBuffer3D;
   import flash.display3D.Program3D;
   import flash.display3D.VertexBuffer3D;
   import flash.display3D.textures.TextureBase;
   import flash.geom.ColorTransform;
   import flash.geom.Matrix;
   import flash.geom.Matrix3D;
   import flash.geom.Rectangle;
   import kabam.rotmg.stage3D.GraphicsFillExtra;
   import kabam.rotmg.stage3D.proxies.Context3DProxy;
   import kabam.rotmg.stage3D.proxies.IndexBuffer3DProxy;
   import kabam.rotmg.stage3D.proxies.TextureProxy;
   import kabam.rotmg.stage3D.proxies.VertexBuffer3DProxy;
   
   public class Graphic3D
   {
      // Matrix.createGradientBox maps a 1638.4-unit gradient square onto the box (a = width / 1638.4).
      private static const GRADIENT_BOX_SIZE:Number = 1638.4;

      // Batched shadow (radial gradient) quads. Per-vertex float layout: position + alphaEdge
      // (4), uv (2), rgb + alphaCenter (4). Positions are pre-transformed to NDC on the CPU
      // (same maths as the old shadowTransform + NDC translation), so vc0 stays identity and the
      // shader restores w = 1 from it. Only slots 0-2 and float4/float2 formats are used, exactly
      // like the sprite and model paths; exotic attribute formats broke some drivers.
      private static const SHADOW_FLOATS:int = 10;
      private static const SHADOW_CAP:int = 256;   // shadows per flush; overflow flushes mid-cluster
      private static const SHADOW_RING:int = 2;

      // Positions of the shared sprite quad (VertexBufferFactory), in the same vertex order.
      private static const UNIT_QUAD_XYZ:Vector.<Number> = new <Number>[-0.5,0.5,0, 0.5,0.5,0, -0.5,-0.5,0, 0.5,-0.5,0];
      // Shared zero uv offset for fills with no extras bit. Read-only in batchQuad;
      // never written, so one instance serves all plain quads with no allocation.
      private static const ZERO_OFFSET:Vector.<Number> = new <Number>[0,0,0,0];
      private static const IDENTITY:Matrix3D = new Matrix3D();

      /** Fractional part in [0,1): maps unbounded scroll offsets into a tilable slot. */
      private static function fract(v:Number) : Number
      {
         return v - Math.floor(v);
      }

      // Deferred draw commands recorded by the batch pass (see batchBegin).
      public static const CMD_RUN:int = 0;      // arg = run index
      public static const CMD_QUAD:int = 1;     // arg = graphicsData index; per-quad drawQuad path
      public static const CMD_SHADOW:int = 2;   // arg = graphicsData index
      public static const CMD_MODEL:int = 3;    // next 3D model

      // Static tile cache handoff, written by Map.draw every frame before dispatch:
      // tileStaticEnd_ is the graphicsData_ length after the static tile pass (0 on
      // cache-hit frames, whose graphicsData_ holds only dynamic triples), and
      // tileCacheHit_ is checkTileCache's verdict for this frame.
      public var tileStaticEnd_:int = 0;
      public var tileCacheHit_:Boolean = false;
      // Set by the renderer around the static tile walk; batchQuad records touched
      // pages/proxies while set so hit frames can stamp atlas/individual LRU.
      public var recordingTiles_:Boolean = false;

      private static const INITIAL_CAPACITY:int = 4096;
      private static const MAX_CAPACITY:int = 16383;  // 16-bit indices: 65532 vertices

      public var texture:TextureProxy;
      public var matrix3D:Matrix3D;
      public var context3D:Context3DProxy;
      
      [Inject]
      public var textureFactory:TextureFactory;
      
      [Inject]
      public var vertexBuffer:VertexBuffer3DProxy;
      
      [Inject]
      public var indexBuffer:IndexBuffer3DProxy;

      private var bitmapData:BitmapData;
      private var matrix2D:Matrix;
      private var sinkLevel:Number = 0;
      private var offsetMatrix:Vector.<Number>;
      private var vertexBufferCustom:VertexBuffer3D;
      private var shadowVBs:Vector.<VertexBuffer3D>;
      private var shadowVB:VertexBuffer3D;
      private var shadowIB:IndexBuffer3D;
      private var shadowData:Vector.<Number>;
      private var shadowQuads:int = 0;
      private var repeat:Boolean;

      private var sinkOffset:Vector.<Number>;
      private var ctMult:Vector.<Number>;
      private var ctOffset:Vector.<Number>;
      private var rawMatrix3D:Vector.<Number>;

      // --- Fast path state (see drawQuad / drawRun) ---
      // Scratch for the per-quad final transform (previously allocated per frame in Renderer).
      private var finalTransform:Matrix3D;
      // fc2 (multipliers) and fc3 (offsets) uploaded together in one call.
      private var ctConstants:Vector.<Number>;
      // Context3D state we know is currently bound; avoids redundant native calls between quads.
      private var stateTexture:TextureBase;
      private var stateRepeat:int = -1;
      private var stateVB:VertexBuffer3D;
      private var stateSlot2Cleared:Boolean = false;
      private var stateIdentityVC0:Boolean = false;
      private var stateOffsetValid:Boolean = false;
      private var stateOffset0:Number = 0;
      private var stateOffset1:Number = 0;
      private var stateOffset2:Number = 0;
      private var stateOffset3:Number = 0;
      private var stateCtValid:Boolean = false;

      // --- Batch state ---
      private var frame:int = 0;
      private var bHalfW:Number = 1;
      private var bHalfH:Number = 1;
      private var bNdcX:Number = 0;
      private var bNdcY:Number = 0;
      private var batchCapacity:int = 0;
      // Ring of vertex buffers: writing into a buffer the GPU is still reading (previous frame)
      // makes the driver wait for that frame, which pins the client to the display refresh.
      private static const VB_RING:int = 3;
      private var batchVBs:Vector.<VertexBuffer3D>;
      private var batchVB:VertexBuffer3D;   // this frame's buffer
      private var batchIB:IndexBuffer3D;
      private var batchData:Vector.<Number>;
      public var batchQuads:int = 0;
      private var batchOverflow:Boolean = false;
      private var xformed:Vector.<Number>;
      private var offsetScratch:Vector.<Number>;
      public var cmdType:Vector.<int>;
      public var cmdArg:Vector.<int>;
      public var cmdCount:int = 0;
      // Software-rasterized triples (fill, path, end) collected during the phase-1 walk so the
      // caller can blit them on the display list without re-scanning the frame's graphics data.
      public var softwareData:Vector.<IGraphicsData>;
      private var runFirstQuad:Vector.<int>;
      private var runQuadCount:Vector.<int>;
      private var runTexture:Vector.<TextureBase>;
      private var runRepeat:Vector.<int>;
      private var runConst:Vector.<Number>;   // 12 per run: uv offset (4) + colour transform (8)
      public var runCount:int = 0;
      private var runOpen:Boolean = false;
      // Per-frame caches: consecutive quads usually share one BitmapData, and the
      // batch is the only reader mid-frame, so memoizing the last lookup skips
      // repeat Dictionary hits. Reset in batchBegin.
      private var lastCtBmd:BitmapData = null;
      private var lastCt:ColorTransform = null;
      private var lastAtlasBmd:BitmapData = null;
      private var lastAtlasEntry:AtlasEntry = null;
      private var lastTiledBmd:BitmapData = null;
      private var lastTiledEntry:AtlasEntry = null;

      // --- Static tile snapshot (see snapshotTileCache) ---
      // Static tile quads/verts/runs are a pure function of (map, tileVersion,
      // camera, atlas layout), so a still-camera frame replays them instead of
      // re-running the tile loop and batchQuad. Verts live in tileData_ (same
      // fixed length as batchData; prime swaps the references, release swaps back,
      // so replay copies nothing). Runs/cmds are re-emitted from the copies.
      private var tileValid_:Boolean = false;
      private var tileMap_:Object = null;
      private var tileVersion_:int = -1;
      private var tileAtlas_:SpriteAtlas = null;
      private var tileEvictions_:int = -1;
      private var tilePendingMap_:Object = null;
      private var tilePendingVersion_:int = -1;
      private var tilePendingStill_:Boolean = false;
      private var tilePendingViewKey_:String = null;
      private var tileViewKey_:String = null;
      private var tileData_:Vector.<Number> = null;
      private var tileQuads_:int = 0;
      private var tileRunFirst_:Vector.<int> = new Vector.<int>();
      private var tileRunCount_:Vector.<int> = new Vector.<int>();
      private var tileRunTex_:Vector.<TextureBase> = new Vector.<TextureBase>();
      private var tileRunRep_:Vector.<int> = new Vector.<int>();
      private var tileRunConst_:Vector.<Number> = new Vector.<Number>();
      private var tileRuns_:int = 0;
      private var tileRunOpen_:Boolean = false;
      private var tileSwapped_:Boolean = false;
      private var tilePages_:Vector.<AtlasPage> = new Vector.<AtlasPage>();
      private var tileProxies_:Vector.<TextureProxy> = new Vector.<TextureProxy>();
      private var tileTouchPages_:Vector.<AtlasPage> = new Vector.<AtlasPage>();
      private var tileTouchProxies_:Vector.<TextureProxy> = new Vector.<TextureProxy>();
      // Translation-scroll reuse (see checkTileCache): snapshot camera wToS (16) lets
      // small pure translations shift the replayed verts by (dx,dy) instead of
      // discarding. Sub-pixel shift (float NDC offset): shared tile edges move
      // together, so no new seams vs a full rebuild (identical maths, 1-ulp float
      // drift at most). Pixel-snapped integer scroll was rejected: it would judder
      // vs smooth camera motion and still need the same shift logic plus rounding.
      private var tileWToS_:Vector.<Number> = new Vector.<Number>(16, true);
      private var tileHasWToS_:Boolean = false;
      private var tilePendingWToS_:Vector.<Number> = new Vector.<Number>(16, true);
      public var tileScrollHit_:Boolean = false;
      public var tileScrollDX_:Number = 0;
      public var tileScrollDY_:Number = 0;
      public var tileScrollPX_:Number = 0;
      public var tileScrollPY_:Number = 0;
      public var tileScrollDist_:Number = 0;
      public var tileStillHits_:int = 0;
      public var tileScrollHits_:int = 0;
      public var tileScrollMisses_:int = 0;
      public var tileMisses_:int = 0;
      // Per-run NDC bboxes (minX,minY,maxX,maxY) for off-screen run culling in
      // primeTileCache, plus the visible NDC window they are tested against.
      // Bboxes are snapshot-space; scroll hits shift them by (dx,dy), still hits
      // use them as-is. Rotation/zoom/resize always miss, so the stored window
      // (same viewKey inputs as the verts) stays valid for the snapshot's life.
      private var tileRunBox_:Vector.<Number> = new Vector.<Number>();
      private var tilePendingClip_:Vector.<Number> = new Vector.<Number>(4, true);
      private var tileWinX0_:Number = 0;
      private var tileWinX1_:Number = 0;
      private var tileWinY0_:Number = 0;
      private var tileWinY1_:Number = 0;
      // Per-frame replay stats for the profiler readout (see Renderer): runs
      // actually emitted as commands, and runs skipped as fully off-screen.
      // -1 drawn means prime never ran (miss path draws everything: all runs).
      public var tileDrawnRuns_:int = -1;
      public var tileCulledRuns_:int = 0;
      // Non-run command mix for the profiler readout (see Renderer): per-quad
      // fallback draws, 3D model draws and shadow marks this frame. Counted only
      // on the unbatchable path, so batched quads pay nothing for this.
      public var quadMarks_:int = 0;
      public var modelMarks_:int = 0;
      public var shadowMarks_:int = 0;
      // Max pure-translation reuse distance in screen pixels (wToS units, 50 per
      // tile at zoom 1). Static snapshot overdraws the clip rect by a larger
      // margin (see Face3D.clipMargin_), so scrolls within this stay covered.
      // Sized from profiler data: random-offset grass tiles each form their own
      // run, so every off-screen margin tile costs a draw call each frame. A
      // smaller margin halves that tax; the price is a resnapshot (one full tile
      // walk) roughly every MAX/4px of continuous motion instead of twice as far.
      private static const TILE_SCROLL_MAX_PX:Number = 32;
      
      public function Graphic3D()
      {
         this.matrix3D = new Matrix3D();
         this.sinkOffset = new Vector.<Number>(4, true);
         this.ctMult = new Vector.<Number>(4, true);
         this.ctOffset = new Vector.<Number>(4, true);
         this.rawMatrix3D = new Vector.<Number>(16, true);
         this.finalTransform = new Matrix3D();
         this.ctConstants = new Vector.<Number>(8, true);
         this.xformed = new Vector.<Number>(12, true);
         this.offsetScratch = new Vector.<Number>(4, true);
         this.cmdType = new Vector.<int>();
         this.cmdArg = new Vector.<int>();
         this.softwareData = new Vector.<IGraphicsData>();
         this.runFirstQuad = new Vector.<int>();
         this.runQuadCount = new Vector.<int>();
         this.runTexture = new Vector.<TextureBase>();
         this.runRepeat = new Vector.<int>();
         this.runConst = new Vector.<Number>();
         super();
      }

      /**
       * Forget what we believe is bound on the Context3D. Call at the start of a render pass and
       * after anything else (shadow program, 3D models, post effects) touches program / texture /
       * vertex buffer state.
       */
      public function invalidateState() : void
      {
         this.stateTexture = null;
         this.stateRepeat = -1;
         this.stateVB = null;
         this.stateSlot2Cleared = false;
         this.stateIdentityVC0 = false;
         this.stateOffsetValid = false;
         this.stateCtValid = false;
      }

      // ------------------------------------------------------------------------------------
      // Batched sprite quads
      //
      // Phase 1 (batchBegin / batchQuad / batchMark): walk the frame's graphics data in draw
      // order. Each ordinary sprite quad has its final matrix built with the same Matrix3D chain
      // as drawQuad, the unit quad is transformed with it (Matrix3D.transformVectors) and the
      // resulting NDC positions plus atlas uvs are appended to one vertex array. Consecutive quads
      // that share texture page, program (repeat flag), uv-offset constant and colour-transform
      // constant form a "run". Anything else (shadows, 3D models, custom-vertex-buffer walls) is
      // recorded as a command so it is still drawn at exactly the same point in the order.
      //
      // Phase 2 (batchUpload / drawRun): upload the vertex array once and draw each run with a
      // single drawTriangles. The vertex program is unchanged; vc0 is the identity, so the GPU
      // passes the pre-transformed positions through.
      // ------------------------------------------------------------------------------------

      public function batchBegin(c3d:Context3D, halfW:Number, halfH:Number, ndcX:Number, ndcY:Number) : void
      {
         this.frame++;
         TextureFactory.frame = this.frame;
         var atlas:SpriteAtlas = this.textureFactory.getAtlas();
         atlas.beginFrame();
         if(FrameProfiler.enabled)
         {
            FrameProfiler.atlasInfo = "atlas pages " + atlas.pageCount + " uploads " + atlas.uploads + " evictions " + atlas.evictions + (SpriteAtlas.USE_RTT ? " (rtt)" : " (cpu)");
         }
         this.bHalfW = halfW;
         this.bHalfH = halfH;
         this.bNdcX = ndcX;
         this.bNdcY = ndcY;
         var wanted:int = this.batchCapacity;
         if(wanted == 0)
         {
            wanted = INITIAL_CAPACITY;
         }
         else if(this.batchOverflow && wanted < MAX_CAPACITY)
         {
            wanted = Math.min(wanted * 2,MAX_CAPACITY);
         }
         if(wanted != this.batchCapacity)
         {
            this.createBatchBuffers(c3d,wanted);
         }
         this.batchVB = this.batchVBs[this.frame % VB_RING];
         this.batchOverflow = false;
         this.batchQuads = 0;
         this.shadowBatchBegin(c3d);
         this.cmdCount = 0;
         this.runCount = 0;
         this.runOpen = false;
         // Tile snapshot walk state. A swapped snapshot vector (missed releaseTileCache
         // after an exception mid-frame) is restored first so batchData is always the
         // ring vector here. tileCacheHit_/tileStaticEnd_ are Map-owned per frame.
         if(this.tileSwapped_)
         {
            var swapTmp:Vector.<Number> = this.batchData;
            this.batchData = this.tileData_;
            this.tileData_ = swapTmp;
            this.tileSwapped_ = false;
         }
         this.recordingTiles_ = false;
         this.tileTouchPages_.length = 0;
         this.tileTouchProxies_.length = 0;
         this.tileDrawnRuns_ = -1;
         this.tileCulledRuns_ = 0;
         this.quadMarks_ = 0;
         this.modelMarks_ = 0;
         this.shadowMarks_ = 0;
         this.lastCtBmd = null;
         this.lastAtlasBmd = null;
         this.lastAtlasEntry = null;
         this.lastTiledBmd = null;
         this.lastTiledEntry = null;
         this.softwareData.length = 0;
      }

      /**
       * Record one software-rasterized triple (fill at `index`, plus its path and end items).
       * Called by the phase-1 walk, which already evaluates the software predicate per item.
       */
      public function pushSoftware(graphicsDatas:Vector.<IGraphicsData>, index:int) : void
      {
         this.softwareData.push(graphicsDatas[index],graphicsDatas[index + 1],graphicsDatas[index + 2]);
      }

      private function createBatchBuffers(c3d:Context3D, capacity:int) : void
      {
         this.disposeBatchBuffers();
         this.batchCapacity = capacity;
         this.batchData = new Vector.<Number>(capacity * 20,true);
         this.batchVBs = new Vector.<VertexBuffer3D>(VB_RING,true);
         var vb:VertexBuffer3D = null;
         for(var i:int = 0; i < VB_RING; i++)
         {
            vb = c3d.createVertexBuffer(capacity * 4,5,Context3DBufferUsage.DYNAMIC_DRAW);
            // Stage3D rejects draws from a buffer that has never been filled end to end
            // ("Stream 0 is invalid", silent with error checking off). One full upload at creation
            // makes the per-frame partial uploads in batchUpload() valid.
            vb.uploadFromVector(this.batchData,0,capacity * 4);
            this.batchVBs[i] = vb;
         }
         this.batchIB = c3d.createIndexBuffer(capacity * 6);
         var idx:Vector.<uint> = new Vector.<uint>(capacity * 6,true);
         var p:int = 0;
         var v:uint = 0;
         for(var q:int = 0; q < capacity; q++)
         {
            v = q * 4;
            idx[p++] = v;
            idx[p++] = v + 1;
            idx[p++] = v + 2;
            idx[p++] = v + 2;
            idx[p++] = v + 1;
            idx[p++] = v + 3;
         }
         this.batchIB.uploadFromVector(idx,0,capacity * 6);
      }

      /** Called by the renderer when the context is lost / recreated so buffers are rebuilt. */
      public function disposeBatchBuffers() : void
      {
         if(this.batchVBs != null)
         {
            for(var i:int = 0; i < this.batchVBs.length; i++)
            {
               this.batchVBs[i].dispose();
            }
            this.batchVBs = null;
         }
         if(this.batchIB != null)
         {
            this.batchIB.dispose();
            this.batchIB = null;
         }
         this.batchVB = null;
         this.batchCapacity = 0;
         if(this.shadowVBs != null)
         {
            for(var s:int = 0; s < this.shadowVBs.length; s++)
            {
               this.shadowVBs[s].dispose();
            }
            this.shadowVBs = null;
         }
         if(this.shadowIB != null)
         {
            this.shadowIB.dispose();
            this.shadowIB = null;
         }
         this.shadowVB = null;
         this.shadowData = null;
         this.shadowQuads = 0;
      }

      /** Drops the tile snapshot (map change, see Map.dispose). */
      public function invalidateTileCache() : void
      {
         this.tileValid_ = false;
         this.tileCacheHit_ = false;
         this.tileScrollHit_ = false;
         this.tileScrollDX_ = 0;
         this.tileScrollDY_ = 0;
         this.tileScrollPX_ = 0;
         this.tileScrollPY_ = 0;
         this.tileScrollDist_ = 0;
         this.tileHasWToS_ = false;
         this.tileRunBox_.length = 0;
         this.tileWinX0_ = this.tileWinX1_ = this.tileWinY0_ = this.tileWinY1_ = 0;
         this.tileDrawnRuns_ = -1;
         this.tileCulledRuns_ = 0;
         this.tileMap_ = null;
         this.tileAtlas_ = null;
         this.tilePendingMap_ = null;
         this.tileViewKey_ = null;
         this.tilePendingViewKey_ = null;
         this.tileQuads_ = 0;
         this.tileRuns_ = 0;
         this.tileRunFirst_.length = 0;
         this.tileRunCount_.length = 0;
         this.tileRunTex_.length = 0;
         this.tileRunRep_.length = 0;
         this.tileRunConst_.length = 0;
         this.tilePages_.length = 0;
         this.tileProxies_.length = 0;
         if(this.tileSwapped_)
         {
            var tmp:Vector.<Number> = this.batchData;
            this.batchData = this.tileData_;
            this.tileData_ = tmp;
            this.tileSwapped_ = false;
         }
      }

      /**
       * Tile-cache verdict for this frame, called by Map.draw before the tile loop.
       * Still hit: same map/version/atlas, still camera, same viewKey. Scroll hit:
       * same base but a small pure camera translation (wToS basis identical, only
       * the translation row moved within TILE_SCROLL_MAX_PX): the snapshot verts
       * shift by (dx,dy) in primeTileCache instead of rebuilding. Any rotation
       * (basis differs), zoom/resize (viewKey differs), eviction, map/version
       * change or large jump is a miss. Pure decision; priming happens in
       * primeTileCache after batchBegin (so LRU stamps use the current serial).
       * wToS is the camera world-to-screen matrix (16 numbers); null forces a miss.
       * clip is the camera clip rect in screen (wToS) units; its snapshot copy feeds
       * the run-cull window, so it is only read on miss frames (copied, never kept).
       */
      public function checkTileCache(map:Object, version:int, still:Boolean, gpu:Boolean, viewKey:String, wToS:Vector.<Number>, clip:Rectangle) : Boolean
      {
         // !gpu forces a miss (and clears a stale hit): software frames emit the full
         // spatial triple stream, so priming a snapshot would double-draw statics.
         // viewKey covers every batch-space input cameraStill cannot see (backbuffer
         // size, zoom, centerOnPlayer, inGame): batch verts bake the NDC transform,
         // so any of those changing must rebuild even with an identical camera.
         var base:Boolean = gpu && this.tileValid_ && this.tileMap_ == map
            && this.tileVersion_ == version && viewKey == this.tileViewKey_;
         var atlas:SpriteAtlas = null;
         if(base)
         {
            atlas = this.textureFactory.getAtlas();
            base = atlas == this.tileAtlas_ && atlas.evictions == this.tileEvictions_;
         }
         var hit:Boolean = false;
         var scroll:Boolean = false;
         this.tileScrollPX_ = 0;
         this.tileScrollPY_ = 0;
         this.tileScrollDist_ = 0;
         this.tileScrollDX_ = 0;
         this.tileScrollDY_ = 0;
         if(base)
         {
            if(still)
            {
               // still means identical to the PREVIOUS frame, not to the snapshot
               // base (scroll hits never move the base). Moving 1-2 tiles then
               // stopping replays the stale base unshifted without this, visibly
               // jumping tiles back. Require a bit-identical wToS to the base;
               // anything else misses once and rebuilds at the stopped position.
               if(wToS != null && this.tileHasWToS_)
               {
                  var same:Boolean = true;
                  for(var si:int = 0; si < 16; si++)
                  {
                     if(wToS[si] != this.tileWToS_[si])
                     {
                        same = false;
                        break;
                     }
                  }
                  if(same)
                  {
                     hit = true;
                     scroll = false;
                  }
               }
            }
            else if(wToS != null && this.tileHasWToS_)
            {
               // Pure-translation test: basis rows (0..11) plus depth/w (14,15)
               // identical; only the screen translation (12,13) moved. Rotation,
               // however small, changes the linear part of every tile matrix, so
               // a uniform shift cannot cover it.
               var pure:Boolean = true;
               for(var bi:int = 0; bi < 12; bi++)
               {
                  if(wToS[bi] != this.tileWToS_[bi])
                  {
                     pure = false;
                     break;
                  }
               }
               if(pure && (wToS[14] != this.tileWToS_[14] || wToS[15] != this.tileWToS_[15]))
               {
                  pure = false;
               }
               if(pure)
               {
                  var px:Number = wToS[12] - this.tileWToS_[12];
                  var py:Number = wToS[13] - this.tileWToS_[13];
                  var dist:Number = Math.sqrt(px * px + py * py);
                  if(dist <= TILE_SCROLL_MAX_PX && dist > 0)
                  {
                     hit = true;
                     scroll = true;
                     this.tileScrollPX_ = px;
                     this.tileScrollPY_ = py;
                     this.tileScrollDist_ = dist;
                  }
                  else if(dist == 0)
                  {
                     // Camera matrix identical but still flag false (clip rounding
                     // edge): treat as a still hit, no shift needed.
                     hit = true;
                     scroll = false;
                  }
               }
            }
         }
         if(hit)
         {
            if(scroll)
            {
               this.tileScrollHits_++;
            }
            else
            {
               this.tileStillHits_++;
            }
         }
         else
         {
            this.tileMisses_++;
            // Scroll miss: same map/version/viewKey/atlas but rotation or too far
            // (user verifies these during frequent camera rotation).
            if(base && !still)
            {
               this.tileScrollMisses_++;
            }
            this.tilePendingMap_ = map;
            this.tilePendingVersion_ = version;
            this.tilePendingStill_ = still;
            this.tilePendingViewKey_ = viewKey;
            if(clip != null)
            {
               this.tilePendingClip_[0] = clip.x;
               this.tilePendingClip_[1] = clip.y;
               this.tilePendingClip_[2] = clip.width;
               this.tilePendingClip_[3] = clip.height;
            }
            if(wToS != null)
            {
               for(var pi:int = 0; pi < 16; pi++)
               {
                  this.tilePendingWToS_[pi] = wToS[pi];
               }
            }
            this.tileScrollPX_ = 0;
            this.tileScrollPY_ = 0;
            this.tileScrollDist_ = 0;
         }
         this.tileCacheHit_ = hit;
         this.tileScrollHit_ = scroll;
         return hit;
      }

      /**
       * Replays the snapshot into the fresh accumulators (after batchBegin).
       * Still hits swap the vertex vectors so the tile verts upload with no copy.
       * Scroll hits copy with a uniform NDC shift (dx,dy): batch verts bake
       * screen tx/halfW + ndcX and -ty/halfH + ndcY, and a pure camera translation
       * moves every tile's tx,ty by the same (px,py), so shifting all verts by
       * (px/halfW, -py/halfH) reproduces the rebuild bit-for-bit (1-ulp drift).
       * Copying keeps the snapshot base pristine (in-place shifts would drift it);
       * runs/cmds/consts replay unchanged (uv offsets and tints are translation
       * invariant). Stamps touched pages/proxies so LRU cannot reclaim them.
       * Returns false when the snapshot no longer fits (batch capacity changed);
       * the caller then walks the whole frame as dynamic, which stays correct.
       */
      public function primeTileCache() : Boolean
      {
         if(this.tileData_ == null || this.tileData_.length != this.batchData.length)
         {
            this.tileValid_ = false;
            return false;
         }
         if(this.tileScrollHit_)
         {
            // Scroll path must classify identically to the still path: static runs
            // never contain software triples (snapshot requires a clean runs-only
            // prefix), so replaying runs plus the dynamic suffix preserves the
            // pushSoftware contract.
            if(this.bHalfW == 0 || this.bHalfH == 0)
            {
               this.tileValid_ = false;
               return false;
            }
            var dx:Number = this.tileScrollPX_ / this.bHalfW;
            var dy:Number = -this.tileScrollPY_ / this.bHalfH;
            this.tileScrollDX_ = dx;
            this.tileScrollDY_ = dy;
            var src:Vector.<Number> = this.tileData_;
            var dst:Vector.<Number> = this.batchData;
            var count:int = this.tileQuads_ * 20;
            for(var vi:int = 0; vi < count; vi += 5)
            {
               dst[vi] = src[vi] + dx;
               dst[vi + 1] = src[vi + 1] + dy;
               dst[vi + 2] = src[vi + 2];
               dst[vi + 3] = src[vi + 3];
               dst[vi + 4] = src[vi + 4];
            }
            this.batchQuads = this.tileQuads_;
         }
         else
         {
            var swapTmp:Vector.<Number> = this.batchData;
            this.batchData = this.tileData_;
            this.tileData_ = swapTmp;
            this.tileSwapped_ = true;
            this.batchQuads = this.tileQuads_;
         }
         // Re-emit tile runs, skipping runs fully outside the stored visible
         // window (off-screen overdraw margin on every hit frame). Run ids stay
         // stable (runCount keeps the full id space for the dynamic suffix), only
         // emitted commands shrink. runConst is intentionally not restored: tile
         // content is version-guarded identical, so the ids reused here still hold
         // the snapshot's constants from the last rebuild.
         var runs:int = this.tileRuns_;
         var cdx:Number = this.tileScrollHit_ ? this.tileScrollDX_ : 0;
         var cdy:Number = this.tileScrollHit_ ? this.tileScrollDY_ : 0;
         var emit:int = 0;
         var lastEmit:int = -1;
         var bx:Vector.<Number> = this.tileRunBox_;
         var hasBox:Boolean = bx.length >= runs * 4;
         for(var i:int = 0; i < runs; i++)
         {
            this.runFirstQuad[i] = this.tileRunFirst_[i];
            this.runQuadCount[i] = this.tileRunCount_[i];
            this.runTexture[i] = this.tileRunTex_[i];
            this.runRepeat[i] = this.tileRunRep_[i];
            // No bbox (old snapshot from before this feature): draw everything.
            var visible:Boolean = !hasBox;
            if(hasBox)
            {
               var b:int = i * 4;
               visible = !(bx[b] + cdx > this.tileWinX1_ || bx[b + 2] + cdx < this.tileWinX0_
                  || bx[b + 1] + cdy > this.tileWinY1_ || bx[b + 3] + cdy < this.tileWinY0_);
            }
            if(visible)
            {
               this.cmdType[emit] = CMD_RUN;
               this.cmdArg[emit] = i;
               emit++;
               lastEmit = i;
            }
         }
         this.runCount = runs;
         this.cmdCount = emit;
         // A merged dynamic suffix may only extend the last run when that run was
         // actually emitted; extending a culled run would draw into the void.
         this.runOpen = this.tileRunOpen_ && lastEmit == runs - 1;
         this.tileDrawnRuns_ = emit;
         this.tileCulledRuns_ = runs - emit;
         var pages:Vector.<AtlasPage> = this.tilePages_;
         for(i = 0; i < pages.length; i++)
         {
            pages[i].lastUsed = this.frame;
         }
         var proxies:Vector.<TextureProxy> = this.tileProxies_;
         for(i = 0; i < proxies.length; i++)
         {
            proxies[i].lastUsed = this.frame;
         }
         return true;
      }

      /** Restores the ring vertex vector after a primed frame drew. Idempotent. */
      public function releaseTileCache() : void
      {
         if(this.tileSwapped_)
         {
            var tmp:Vector.<Number> = this.batchData;
            this.batchData = this.tileData_;
            this.tileData_ = tmp;
            this.tileSwapped_ = false;
         }
      }

      /**
       * Snapshots the just-walked static tile prefix ([0, batchQuads/cmdCount) at the
       * call). Attempted on every clean rebuild (still or pure-translation miss):
       * refreshing the base on translation misses keeps future scroll deltas small,
       * while rotation/zoom/resize frames simply establish the next base. Requires
       * a clean tile region (runs only, no software triples, no overflow); anything
       * else leaves the frame correct but uncached (and preserves the old base when
       * one exists). Returns the verdict for the atlas readout.
       */
      public function snapshotTileCache() : Boolean
      {
         this.recordingTiles_ = false;
         var cc:int = this.cmdCount;
         for(var i:int = 0; i < cc; i++)
         {
            if(this.cmdType[i] != CMD_RUN)
            {
               this.tileValid_ = false;
               return false;
            }
         }
         if(this.softwareData.length != 0 || this.batchOverflow)
         {
            this.tileValid_ = false;
            return false;
         }
         var quads:int = this.batchQuads;
         if(this.tileData_ == null || this.tileData_.length != this.batchData.length)
         {
            this.tileData_ = new Vector.<Number>(this.batchData.length,true);
         }
         var src:Vector.<Number> = this.batchData;
         var dst:Vector.<Number> = this.tileData_;
         var count:int = quads * 20;
         for(i = 0; i < count; i++)
         {
            dst[i] = src[i];
         }
         this.tileQuads_ = quads;
         var runs:int = this.runCount;
         this.tileRunFirst_.length = runs;
         this.tileRunCount_.length = runs;
         this.tileRunTex_.length = runs;
         this.tileRunRep_.length = runs;
         this.tileRunConst_.length = runs * 12;
         for(i = 0; i < runs; i++)
         {
            this.tileRunFirst_[i] = this.runFirstQuad[i];
            this.tileRunCount_[i] = this.runQuadCount[i];
            this.tileRunTex_[i] = this.runTexture[i];
            this.tileRunRep_[i] = this.runRepeat[i];
         }
         var rc:Vector.<Number> = this.runConst;
         var tc:Vector.<Number> = this.tileRunConst_;
         var cn:int = runs * 12;
         for(i = 0; i < cn; i++)
         {
            tc[i] = rc[i];
         }
         this.tileRuns_ = runs;
         this.tileRunOpen_ = this.runOpen;
         // Visible NDC window for run culling (same inputs as the verts, so the
         // stored window stays valid for the snapshot's life: any zoom/resize
         // changes viewKey and misses). 2px slack so float drift can never clip
         // a visible edge; culled runs only ever cost vertex upload, never pixels.
         var hw:Number = this.bHalfW;
         var hh:Number = this.bHalfH;
         if(hw == 0 || hh == 0)
         {
            this.tileWinX0_ = -1e9;
            this.tileWinX1_ = 1e9;
            this.tileWinY0_ = -1e9;
            this.tileWinY1_ = 1e9;
         }
         else
         {
            var pc:Vector.<Number> = this.tilePendingClip_;
            var slx:Number = 2 / hw;
            var sly:Number = 2 / hh;
            this.tileWinX0_ = pc[0] / hw + this.bNdcX - slx;
            this.tileWinX1_ = (pc[0] + pc[2]) / hw + this.bNdcX + slx;
            this.tileWinY0_ = -(pc[1] + pc[3]) / hh + this.bNdcY - sly;
            this.tileWinY1_ = -pc[1] / hh + this.bNdcY + sly;
         }
         // Per-run NDC bboxes over the snapshot verts (miss frames only).
         this.tileRunBox_.length = runs * 4;
         var bdv:Vector.<Number> = this.batchData;
         for(var br:int = 0; br < runs; br++)
         {
            var bq0:int = this.tileRunFirst_[br];
            var bqn:int = bq0 + this.tileRunCount_[br];
            var bminx:Number = Number.MAX_VALUE;
            var bminy:Number = Number.MAX_VALUE;
            var bmaxx:Number = -Number.MAX_VALUE;
            var bmaxy:Number = -Number.MAX_VALUE;
            for(var bq:int = bq0; bq < bqn; bq++)
            {
               var bp:int = bq * 20;
               for(var bv:int = 0; bv < 4; bv++)
               {
                  var bxx:Number = bdv[bp + bv * 5];
                  var byy:Number = bdv[bp + bv * 5 + 1];
                  if(bxx < bminx)
                  {
                     bminx = bxx;
                  }
                  if(bxx > bmaxx)
                  {
                     bmaxx = bxx;
                  }
                  if(byy < bminy)
                  {
                     bminy = byy;
                  }
                  if(byy > bmaxy)
                  {
                     bmaxy = byy;
                  }
               }
            }
            var bo:int = br * 4;
            this.tileRunBox_[bo] = bminx;
            this.tileRunBox_[bo + 1] = bminy;
            this.tileRunBox_[bo + 2] = bmaxx;
            this.tileRunBox_[bo + 3] = bmaxy;
         }
         this.tilePages_.length = 0;
         var tp:Vector.<AtlasPage> = this.tileTouchPages_;
         for(i = 0; i < tp.length; i++)
         {
            if(this.tilePages_.indexOf(tp[i]) == -1)
            {
               this.tilePages_.push(tp[i]);
            }
         }
         tp.length = 0;
         this.tileProxies_.length = 0;
         var tx:Vector.<TextureProxy> = this.tileTouchProxies_;
         for(i = 0; i < tx.length; i++)
         {
            if(this.tileProxies_.indexOf(tx[i]) == -1)
            {
               this.tileProxies_.push(tx[i]);
            }
         }
         tx.length = 0;
         this.tileMap_ = this.tilePendingMap_;
         this.tileVersion_ = this.tilePendingVersion_;
         this.tileViewKey_ = this.tilePendingViewKey_;
         for(var wi:int = 0; wi < 16; wi++)
         {
            this.tileWToS_[wi] = this.tilePendingWToS_[wi];
         }
         this.tileHasWToS_ = true;
         // A fresh base has zero scroll offset; prime fills the per-frame dx/dy.
         this.tileScrollPX_ = 0;
         this.tileScrollPY_ = 0;
         this.tileScrollDist_ = 0;
         this.tileScrollDX_ = 0;
         this.tileScrollDY_ = 0;
         this.tileScrollHit_ = false;
         var atlas:SpriteAtlas = this.textureFactory.getAtlas();
         this.tileAtlas_ = atlas;
         this.tileEvictions_ = atlas.evictions;
         this.tileValid_ = true;
         return true;
      }

      /**
       * Record a sprite quad. Returns false if the quad cannot be batched (custom vertex buffer,
       * or the batch is full) and must be drawn via drawQuad at this point in the order.
       */
      public function batchQuad(fill:GraphicsBitmapFill) : Boolean
      {
         // One extras lookup replaces three (vertex buffer, uv offset, sink level)
         // for plain fills, which never appear in those tables: particles, static
         // tiles and most objects. Marked fills take the existing slow reads.
         var hasExtra:Boolean = GraphicsFillExtra.hasExtras(fill);
         if(hasExtra && GraphicsFillExtra.getVertexBuffer(fill) != null)
         {
            return false;
         }
         if(this.batchQuads >= this.batchCapacity)
         {
            this.batchOverflow = true;
            return false;
         }
         var bmd:BitmapData = fill.bitmapData;
         var texBase:TextureBase = null;
         var w:int = 0;
         var h:int = 0;
         var u0:Number = 0;
         var v0:Number = 0;
         var u1:Number = 1;
         var v1:Number = 1;
         // uv offset (vc4): animated tiles scroll via the shader offset. Offset or
         // repeating fills use tilable atlas slots holding a 2x2 replication, so any
         // fractional offset still samples continuous content with the clamp sampler
         // and batches exactly like plain quads. Only sprites with no atlas entry
         // (too large, page pressure, custom vertex buffers) keep individual textures.
         // Water sink is separate: clip pixels counted down from the sprite's bottom
         // rows (see GameObject.draw), applied to the v1 edge below so the tile
         // beneath shows through like the display-list clip path.
         var offset:Vector.<Number> = hasExtra ? GraphicsFillExtra.getOffsetUV(fill) : ZERO_OFFSET;
         var sink:Number = hasExtra ? GraphicsFillExtra.getSinkLevel(fill) : 0;
         var o0:Number = offset[0];
         var o1:Number = offset[1];
         var tilable:Boolean = fill.repeat || o0 != 0 || o1 != 0 || offset[2] != 0 || offset[3] != 0;
         var entry:AtlasEntry = null;
         if(!tilable)
         {
            if(bmd == this.lastAtlasBmd && this.lastAtlasEntry != null
               && this.lastAtlasEntry.generation == this.lastAtlasEntry.page.generation)
            {
               this.lastAtlasEntry.page.lastUsed = this.frame;
               entry = this.lastAtlasEntry;
            }
            else
            {
               entry = this.textureFactory.getAtlas().get(bmd,this.frame);
               if(entry != null)
               {
                  this.lastAtlasBmd = bmd;
                  this.lastAtlasEntry = entry;
               }
            }
         }
         else
         {
            if(bmd == this.lastTiledBmd && this.lastTiledEntry != null
               && this.lastTiledEntry.generation == this.lastTiledEntry.page.generation)
            {
               this.lastTiledEntry.page.lastUsed = this.frame;
               entry = this.lastTiledEntry;
            }
            else
            {
               entry = this.textureFactory.getAtlas().get(bmd,this.frame,true);
               if(entry != null)
               {
                  this.lastTiledBmd = bmd;
                  this.lastTiledEntry = entry;
               }
            }
         }
         // Run key offset (vc4). Atlas quads keep the shader offset so the run key
         // must include it; individual-texture quads bake it into the vertex uvs
         // below so same-texture quads with different offsets still merge.
         var keyO0:Number = 0;
         var keyO1:Number = 0;
         var keyO2:Number = 0;
         var keyO3:Number = 0;
         var tex:TextureProxy = null;
         if(entry != null)
         {
            texBase = entry.page.texture;
            if(this.recordingTiles_)
            {
               // Coalesce consecutive touches (miss frames only): the snapshot dedups
               // this list anyway, so only run boundaries add entries. O(runs), not O(quads).
               var touchPages:Vector.<AtlasPage> = this.tileTouchPages_;
               if(touchPages.length == 0 || touchPages[touchPages.length - 1] != entry.page)
               {
                  touchPages.push(entry.page);
               }
            }
            w = entry.w;
            h = entry.h;
            if(entry.tilable)
            {
               // First copy's rect; the fractional scroll offset lands inside the 2x2
               // block for any value, so same-page/same-offset quads share one run.
               // Batch quads always span one sprite, so the clamp program samples them
               // identically to the old per-texture repeat program.
               u0 = entry.u0;
               v0 = entry.v0;
               u1 = entry.u0 + entry.uSpan;
               v1 = entry.v0 + entry.vSpan;
               keyO0 = fract(o0) * entry.uSpan;
               keyO1 = fract(o1) * entry.vSpan;
            }
            else
            {
               u0 = entry.u0;
               v0 = entry.v0;
               u1 = entry.u1;
               v1 = entry.v1;
            }
         }
         else
         {
            tex = this.textureFactory.make(bmd);
            if(tex == null)
            {
               return true;   // drawQuad draws nothing for this either
            }
            texBase = tex.getTexture();
            if(this.recordingTiles_)
            {
               // Same coalescing as the page list above (see comment there).
               var touchProxies:Vector.<TextureProxy> = this.tileTouchProxies_;
               if(touchProxies.length == 0 || touchProxies[touchProxies.length - 1] != tex)
               {
                  touchProxies.push(tex);
               }
            }
            w = tex.getWidth();
            h = tex.getHeight();
            if(tilable)
            {
               // No atlas slot (too large / page pressure): scroll the old way.
               keyO0 = o0;
               keyO1 = o1;
               keyO2 = offset[2];
               keyO3 = offset[3];
            }
            // Bake the offset into the vertex uvs (identical sampling: the shader
            // added the same offset to the same uvs, repeat wraps either way) so
            // quads sharing texture, program and tint merge into one run instead
            // of one draw each.
            if(keyO0 != 0 || keyO1 != 0 || keyO2 != 0 || keyO3 != 0)
            {
               u0 += keyO0;
               v0 += keyO1;
               u1 += keyO0;
               v1 += keyO1;
               keyO0 = keyO1 = keyO2 = keyO3 = 0;
            }
         }
         // Water-sink clip: hide the bottom sink sprite rows so the tile beneath
         // shows through, mirroring the display-list shortened vS_ path (feet rows
         // never drawn, remaining rows 1:1). Both the v1 edge and the quad height
         // shrink to the visible-row count: v1 drops the padded rows plus the sunk
         // rows, and the transform below maps exactly those rows onto the same
         // screen rect the display list fills. Per-vertex data, so sunk quads with
         // the same texture/tint still merge into shared runs with vc4 == 0.
         if(sink != 0)
         {
            if(sink >= bmd.height)
            {
               return true;   // fully submerged: display list draws nothing either
            }
            var sinkPadH:Number = entry != null ? entry.h : tex.getHeight();
            var sinkTexH:Number = entry != null ? SpriteAtlas.PAGE_SIZE : tex.getHeight();
            v1 -= (sinkPadH - bmd.height + sink) / sinkTexH;
         }

         // --- vertex transform: scalar fold of the drawQuad Matrix3D chain ---
         // Flash applies prepended ops first, so per corner (x,y) the chain runs:
         // unit nudge (+0.5/-0.5), texture-size scale, 2D fill matrix to screen
         // pixels, NDC divide, NDC shift (same shape as the shadow-batch maths):
         //   X = (a*texW*(x+0.5) - c*texH*(y-0.5) + tx)/halfW + ndcX
         //   Y = (-b*texW*(x+0.5) + d*texH*(y-0.5) - ty)/halfH + ndcY
         // Rewritten as X = Ax*x + Bx*y + Cx, Y = Ay*x + By*y + Cy and evaluated
         // at the four unit corners directly: identical results to transformVectors
         // with none of the per-quad Matrix3D call overhead. (z stays 0, as before.)
         var fm:Matrix = fill.matrix;
         var texH:Number = sink != 0 ? bmd.height - sink : h;
         // NOTE: X-side terms all divide by halfW, Y-side all by halfH. The cross
         // (rotation) terms are the easy ones to get wrong: Bx pairs c with halfW,
         // Ay pairs b with halfH. At zero rotation both are 0, which is why this
         // only shows under camera rotation or rotated sprites (e.g. projectiles).
         var Ax:Number = fm.a * w / this.bHalfW;
         var Bx:Number = -fm.c * texH / this.bHalfW;
         var Cx:Number = (0.5 * fm.a * w + 0.5 * fm.c * texH + fm.tx) / this.bHalfW + this.bNdcX;
         var Ay:Number = -fm.b * w / this.bHalfH;
         var By:Number = fm.d * texH / this.bHalfH;
         var Cy:Number = (-0.5 * fm.b * w - 0.5 * fm.d * texH - fm.ty) / this.bHalfH + this.bNdcY;
         var hAx:Number = 0.5 * Ax;
         var hBx:Number = 0.5 * Bx;
         var hAy:Number = 0.5 * Ay;
         var hBy:Number = 0.5 * By;
         var out:Vector.<Number> = this.xformed;
         out[0] = Cx - hAx + hBx;  out[1] = Cy - hAy + hBy;  out[2] = 0;
         out[3] = Cx + hAx + hBx;  out[4] = Cy + hAy + hBy;  out[5] = 0;
         out[6] = Cx - hAx - hBx;  out[7] = Cy - hAy - hBy;  out[8] = 0;
         out[9] = Cx + hAx - hBx;  out[10] = Cy + hAy - hBy; out[11] = 0;

         // --- run state ---
         var ct:ColorTransform = null;
         if(bmd == this.lastCtBmd && this.lastCt != null)
         {
            ct = this.lastCt;
         }
         else
         {
            ct = GraphicsFillExtra.getColorTransform(bmd);
            this.lastCtBmd = bmd;
            this.lastCt = ct;
         }
         // Atlas quads (plain or tilable) always use the clamp program: batch quads
         // span one sprite, so repeat would sample identically. This also lets
         // scrolling quads with a zero fractional offset merge into plain runs.
         var repeatIdx:int = entry != null ? 0 : (fill.repeat ? 1 : 0);
         var rc:Vector.<Number> = this.runConst;
         var r:int = this.runCount - 1;
         var k:int = r * 12;
         var newRun:Boolean = !this.runOpen || this.runTexture[r] != texBase || this.runRepeat[r] != repeatIdx
            || rc[k] != keyO0 || rc[k + 1] != keyO1 || rc[k + 2] != keyO2 || rc[k + 3] != keyO3
            || rc[k + 4] != ct.redMultiplier || rc[k + 5] != ct.greenMultiplier || rc[k + 6] != ct.blueMultiplier || rc[k + 7] != ct.alphaMultiplier
            || rc[k + 8] != ct.redOffset || rc[k + 9] != ct.greenOffset || rc[k + 10] != ct.blueOffset || rc[k + 11] != ct.alphaOffset;
         if(newRun)
         {
            r = this.runCount++;
            k = r * 12;
            this.runFirstQuad[r] = this.batchQuads;
            this.runQuadCount[r] = 0;
            this.runTexture[r] = texBase;
            this.runRepeat[r] = repeatIdx;
            rc[k] = keyO0;
            rc[k + 1] = keyO1;
            rc[k + 2] = keyO2;
            rc[k + 3] = keyO3;
            rc[k + 4] = ct.redMultiplier;
            rc[k + 5] = ct.greenMultiplier;
            rc[k + 6] = ct.blueMultiplier;
            rc[k + 7] = ct.alphaMultiplier;
            rc[k + 8] = ct.redOffset;
            rc[k + 9] = ct.greenOffset;
            rc[k + 10] = ct.blueOffset;
            rc[k + 11] = ct.alphaOffset;
            this.cmdType[this.cmdCount] = CMD_RUN;
            this.cmdArg[this.cmdCount] = r;
            this.cmdCount++;
            this.runOpen = true;
         }
         this.runQuadCount[r]++;

         // --- vertices: xyz from transformVectors, uv from the atlas slot ---
         var d:Vector.<Number> = this.batchData;
         var p:int = this.batchQuads * 20;
         d[p] = out[0];      d[p + 1] = out[1];   d[p + 2] = out[2];   d[p + 3] = u0;  d[p + 4] = v0;
         d[p + 5] = out[3];  d[p + 6] = out[4];   d[p + 7] = out[5];   d[p + 8] = u1;  d[p + 9] = v0;
         d[p + 10] = out[6]; d[p + 11] = out[7];  d[p + 12] = out[8];  d[p + 13] = u0; d[p + 14] = v1;
         d[p + 15] = out[9]; d[p + 16] = out[10]; d[p + 17] = out[11]; d[p + 18] = u1; d[p + 19] = v1;
         this.batchQuads++;
         return true;
      }

      /**
       * Batch one arbitrary screen-space quad with explicit uvs (wall faces).
       * Wall side faces are world-space trapezoids (tapered tops), so unlike sprite
       * quads they are not affine images of the unit square and batchQuad cannot
       * reproduce them; today each such face costs its own CMD_QUAD draw and splits
       * the surrounding sprite runs. The fill matrix is still an affine texture-px
       * to screen-px map fitted to the face, so inverting it yields per-corner uvs
       * under the exact same affine function the display list evaluates: identical
       * texels on any triangulation, 1-ulp float drift at most.
       * Uses the individual-texture route (never the atlas): extrapolated taper uvs
       * can land outside [0,1], where an atlas slot would bleed neighbor sprites
       * while the display list clamps/wraps the face's own texture. Same-shade faces
       * share one proxy/texture, so a whole wall map collapses to a few runs.
       * Only quad paths (8 numbers) are taken; N-gons, non-pow2 textures (padding
       * would move the wrap/clamp edge vs the display list), degenerate matrices,
       * offsets/sinks and batch overflow return false for the legacy CMD_QUAD path.
       */
      public function batchGeneralQuad(fill:GraphicsBitmapFill, path:GraphicsPath) : Boolean
      {
         var bmd:BitmapData = fill.bitmapData;
         if(bmd == null || path == null)
         {
            return false;
         }
         var v:Vector.<Number> = path.data;
         if(v == null || v.length != 8)
         {
            return false;
         }
         if((bmd.width & (bmd.width - 1)) != 0 || (bmd.height & (bmd.height - 1)) != 0)
         {
            return false;
         }
         if(GraphicsFillExtra.hasExtras(fill))
         {
            var off:Vector.<Number> = GraphicsFillExtra.getOffsetUV(fill);
            if(off[0] != 0 || off[1] != 0 || off[2] != 0 || off[3] != 0)
            {
               return false;
            }
            if(GraphicsFillExtra.getSinkLevel(fill) != 0)
            {
               return false;
            }
         }
         var fm:Matrix = fill.matrix;
         if(fm == null)
         {
            return false;
         }
         var det:Number = fm.a * fm.d - fm.b * fm.c;
         if(det > -0.000000001 && det < 0.000000001)
         {
            return false;
         }
         if(this.batchQuads >= this.batchCapacity)
         {
            this.batchOverflow = true;
            return false;
         }
         var tex:TextureProxy = this.textureFactory.make(bmd);
         if(tex == null)
         {
            return true;
         }
         var texBase:TextureBase = tex.getTexture();
         var texW:Number = tex.getWidth();
         var texH:Number = tex.getHeight();
         // Inverse texture-px <- screen-px (fill.matrix maps the other way).
         var ia:Number = fm.d / det;
         var ib:Number = -fm.b / det;
         var ic:Number = -fm.c / det;
         var id:Number = fm.a / det;
         var itx:Number = (fm.c * fm.ty - fm.d * fm.tx) / det;
         var ity:Number = (fm.b * fm.tx - fm.a * fm.ty) / det;
         var hw:Number = this.bHalfW;
         var hh:Number = this.bHalfH;
         var nx:Number = this.bNdcX;
         var ny:Number = this.bNdcY;
         var d:Vector.<Number> = this.batchData;
         var p:int = this.batchQuads * 20;
         for(var i:int = 0; i < 4; i++)
         {
            var sx:Number = v[i * 2];
            var sy:Number = v[i * 2 + 1];
            d[p] = sx / hw + nx;
            d[p + 1] = -sy / hh + ny;
            d[p + 2] = 0;
            d[p + 3] = (ia * sx + ic * sy + itx) / texW;
            d[p + 4] = (ib * sx + id * sy + ity) / texH;
            p += 5;
         }
         var ct:ColorTransform = null;
         if(bmd == this.lastCtBmd && this.lastCt != null)
         {
            ct = this.lastCt;
         }
         else
         {
            ct = GraphicsFillExtra.getColorTransform(bmd);
            this.lastCtBmd = bmd;
            this.lastCt = ct;
         }
         var repeatIdx:int = fill.repeat ? 1 : 0;
         var rc:Vector.<Number> = this.runConst;
         var r:int = this.runCount - 1;
         var k:int = r * 12;
         var newRun:Boolean = !this.runOpen || this.runTexture[r] != texBase || this.runRepeat[r] != repeatIdx
            || rc[k] != 0 || rc[k + 1] != 0 || rc[k + 2] != 0 || rc[k + 3] != 0
            || rc[k + 4] != ct.redMultiplier || rc[k + 5] != ct.greenMultiplier || rc[k + 6] != ct.blueMultiplier || rc[k + 7] != ct.alphaMultiplier
            || rc[k + 8] != ct.redOffset || rc[k + 9] != ct.greenOffset || rc[k + 10] != ct.blueOffset || rc[k + 11] != ct.alphaOffset;
         if(newRun)
         {
            r = this.runCount++;
            k = r * 12;
            this.runFirstQuad[r] = this.batchQuads;
            this.runQuadCount[r] = 0;
            this.runTexture[r] = texBase;
            this.runRepeat[r] = repeatIdx;
            rc[k] = 0;
            rc[k + 1] = 0;
            rc[k + 2] = 0;
            rc[k + 3] = 0;
            rc[k + 4] = ct.redMultiplier;
            rc[k + 5] = ct.greenMultiplier;
            rc[k + 6] = ct.blueMultiplier;
            rc[k + 7] = ct.alphaMultiplier;
            rc[k + 8] = ct.redOffset;
            rc[k + 9] = ct.greenOffset;
            rc[k + 10] = ct.blueOffset;
            rc[k + 11] = ct.alphaOffset;
            this.cmdType[this.cmdCount] = CMD_RUN;
            this.cmdArg[this.cmdCount] = r;
            this.cmdCount++;
            this.runOpen = true;
         }
         this.runQuadCount[r]++;
         this.batchQuads++;
         return true;
      }

      /** Record a non-batched item (shadow, 3D model, per-quad fallback); closes the open run. */
      public function batchMark(type:int, arg:int) : void
      {
         this.runOpen = false;
         if(type == CMD_QUAD)
         {
            this.quadMarks_++;
         }
         else if(type == CMD_MODEL)
         {
            this.modelMarks_++;
         }
         else if(type == CMD_SHADOW)
         {
            this.shadowMarks_++;
         }
         this.cmdType[this.cmdCount] = type;
         this.cmdArg[this.cmdCount] = arg;
         this.cmdCount++;
      }

      /** True if new sprites were added to the atlas this frame and flushAtlas must run. */
      public function hasPendingAtlasUploads() : Boolean
      {
         return this.textureFactory.getAtlas().hasPending();
      }

      /**
       * Pushes new sprites into their atlas pages. Returns true if the render target / context
       * state was touched (render-to-texture mode) and the caller must restore the target; tracked
       * state is invalidated either way.
       */
      public function flushAtlas(c3dProxy:Context3DProxy) : Boolean
      {
         var program:Program3D = Program3DFactory.getInstance().getProgram(c3dProxy,false).getProgram3D();
         this.textureFactory.getAtlas().flush(c3dProxy.GetContext3D(),program);
         this.invalidateState();
         return SpriteAtlas.USE_RTT;
      }

      /** Upload this frame's batched vertices (once). */
      public function batchUpload() : void
      {
         if(this.batchQuads > 0)
         {
            this.batchVB.uploadFromVector(this.batchData,0,this.batchQuads * 4);
         }
      }

      /** Draw one recorded run with a single drawTriangles. */
      public function drawRun(c3dProxy:Context3DProxy, r:int) : void
      {
         var c3d:Context3D = c3dProxy.GetContext3D();
         var repeatIdx:int = this.runRepeat[r];
         if(repeatIdx != this.stateRepeat)
         {
            c3dProxy.setProgram(Program3DFactory.getInstance().getProgram(c3dProxy,repeatIdx == 1));
            this.stateRepeat = repeatIdx;
         }
         var tex:TextureBase = this.runTexture[r];
         if(tex != this.stateTexture)
         {
            c3d.setTextureAt(0,tex);
            this.stateTexture = tex;
         }
         if(this.batchVB != this.stateVB)
         {
            c3d.setVertexBufferAt(0,this.batchVB,0,Context3DVertexBufferFormat.FLOAT_3);
            c3d.setVertexBufferAt(1,this.batchVB,3,Context3DVertexBufferFormat.FLOAT_2);
            this.stateVB = this.batchVB;
         }
         if(!this.stateSlot2Cleared)
         {
            c3d.setVertexBufferAt(2,null);
            this.stateSlot2Cleared = true;
         }
         if(!this.stateIdentityVC0)
         {
            c3dProxy.setProgramConstantsFromMatrix(Context3DProgramType.VERTEX,0,IDENTITY,true);
            this.stateIdentityVC0 = true;
         }
         var rc:Vector.<Number> = this.runConst;
         var k:int = r * 12;
         var o0:Number = rc[k];
         var o1:Number = rc[k + 1];
         var o2:Number = rc[k + 2];
         var o3:Number = rc[k + 3];
         if(!this.stateOffsetValid || o0 != this.stateOffset0 || o1 != this.stateOffset1 || o2 != this.stateOffset2 || o3 != this.stateOffset3)
         {
            var os:Vector.<Number> = this.offsetScratch;
            os[0] = o0;
            os[1] = o1;
            os[2] = o2;
            os[3] = o3;
            c3d.setProgramConstantsFromVector(Context3DProgramType.VERTEX,4,os);
            this.stateOffset0 = o0;
            this.stateOffset1 = o1;
            this.stateOffset2 = o2;
            this.stateOffset3 = o3;
            this.stateOffsetValid = true;
         }
         var cc:Vector.<Number> = this.ctConstants;
         var rm:Number = rc[k + 4];
         var gm:Number = rc[k + 5];
         var bm:Number = rc[k + 6];
         var am:Number = rc[k + 7];
         var ro:Number = rc[k + 8] / 0xFF;
         var go:Number = rc[k + 9] / 0xFF;
         var bo:Number = rc[k + 10] / 0xFF;
         var ao:Number = rc[k + 11] / 0xFF;
         if(!this.stateCtValid || cc[0] != rm || cc[1] != gm || cc[2] != bm || cc[3] != am || cc[4] != ro || cc[5] != go || cc[6] != bo || cc[7] != ao)
         {
            cc[0] = rm;
            cc[1] = gm;
            cc[2] = bm;
            cc[3] = am;
            cc[4] = ro;
            cc[5] = go;
            cc[6] = bo;
            cc[7] = ao;
            c3d.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT,2,cc,2);
            this.stateCtValid = true;
         }
         FrameProfiler.frameDrawCalls++;
         c3d.drawTriangles(this.batchIB,this.runFirstQuad[r] * 6,this.runQuadCount[r] * 2);
      }

      /**
       * Equivalent to setGraphic() + the Renderer's finalTransform maths + render(). The transform
       * is computed with exactly the same Matrix3D calls as before; the saving is that Context3D
       * state calls (program, texture, vertex buffers, uv offset, colour transform) are skipped
       * when unchanged from the previous quad. halfW/halfH are the NDC divisors, ndcX/ndcY the
       * NDC translation. Used for quads the batch cannot take (custom vertex buffers, overflow).
       */
      public function drawQuad(fill:GraphicsBitmapFill, c3dProxy:Context3DProxy, halfW:Number, halfH:Number, ndcX:Number, ndcY:Number) : void
      {
         var bmd:BitmapData = fill.bitmapData;
         var tex:TextureProxy = this.textureFactory.make(bmd);
         if(tex == null)
         {
            return;
         }
         var c3d:Context3D = c3dProxy.GetContext3D();

         // --- program ---
         var repeatIdx:int = fill.repeat ? 1 : 0;
         if(repeatIdx != this.stateRepeat)
         {
            c3dProxy.setProgram(Program3DFactory.getInstance().getProgram(c3dProxy,fill.repeat));
            this.stateRepeat = repeatIdx;
         }

         // --- texture ---
         var texBase:TextureBase = tex.getTexture();
         if(texBase != this.stateTexture)
         {
            c3d.setTextureAt(0,texBase);
            this.stateTexture = texBase;
         }

         // --- vertex buffers ---
         var custom:VertexBuffer3D = GraphicsFillExtra.getVertexBuffer(fill);
         var vb:VertexBuffer3D = custom != null ? custom : this.vertexBuffer.getVertexBuffer3D();
         if(vb != this.stateVB)
         {
            c3d.setVertexBufferAt(0,vb,0,Context3DVertexBufferFormat.FLOAT_3);
            c3d.setVertexBufferAt(1,vb,3,Context3DVertexBufferFormat.FLOAT_2);
            this.stateVB = vb;
         }
         if(!this.stateSlot2Cleared)
         {
            c3d.setVertexBufferAt(2,null);
            this.stateSlot2Cleared = true;
         }

         // --- vertex transform: same Matrix3D chain as setGraphic()/transform() + the Renderer's finalTransform ---
         this.texture = tex;
         this.matrix2D = fill.matrix;
         this.transform();
         var f:Matrix3D = this.finalTransform;
         f.identity();
         f.append(this.matrix3D);
         f.appendScale(1 / halfW,1 / halfH,1);
         f.appendTranslation(ndcX,ndcY,0);
         c3dProxy.setProgramConstantsFromMatrix(Context3DProgramType.VERTEX,0,f,true);
         this.stateIdentityVC0 = false;

         // --- uv offset (vc4): animated tiles scroll; water sink is clip pixels
         // (see batchQuad). This fallback path uses a shared vertex buffer so it
         // cannot clip the v1 edge; shift sampling up by the clip fraction so the
         // feet rows are not shown. Reachable only on batch overflow / custom VBs.
         var offset:Vector.<Number> = GraphicsFillExtra.getOffsetUV(fill);
         var sink:Number = GraphicsFillExtra.getSinkLevel(fill);
         if(sink != 0)
         {
            this.sinkOffset[1] = -(sink / tex.getHeight());
            offset = this.sinkOffset;
         }
         var o0:Number = offset[0];
         var o1:Number = offset[1];
         var o2:Number = offset[2];
         var o3:Number = offset[3];
         if(!this.stateOffsetValid || o0 != this.stateOffset0 || o1 != this.stateOffset1 || o2 != this.stateOffset2 || o3 != this.stateOffset3)
         {
            c3d.setProgramConstantsFromVector(Context3DProgramType.VERTEX,4,offset);
            this.stateOffset0 = o0;
            this.stateOffset1 = o1;
            this.stateOffset2 = o2;
            this.stateOffset3 = o3;
            this.stateOffsetValid = true;
         }

         // --- colour transform (fc2, fc3) ---
         var ct:ColorTransform = GraphicsFillExtra.getColorTransform(bmd);
         var cc:Vector.<Number> = this.ctConstants;
         var rm:Number = ct.redMultiplier;
         var gm:Number = ct.greenMultiplier;
         var bm:Number = ct.blueMultiplier;
         var am:Number = ct.alphaMultiplier;
         var ro:Number = ct.redOffset / 0xFF;
         var go:Number = ct.greenOffset / 0xFF;
         var bo:Number = ct.blueOffset / 0xFF;
         var ao:Number = ct.alphaOffset / 0xFF;
         if(!this.stateCtValid || cc[0] != rm || cc[1] != gm || cc[2] != bm || cc[3] != am || cc[4] != ro || cc[5] != go || cc[6] != bo || cc[7] != ao)
         {
            cc[0] = rm;
            cc[1] = gm;
            cc[2] = bm;
            cc[3] = am;
            cc[4] = ro;
            cc[5] = go;
            cc[6] = bo;
            cc[7] = ao;
            c3d.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT,2,cc,2);
            this.stateCtValid = true;
         }

         c3dProxy.drawTriangles(this.indexBuffer);
      }
      
      public function setGraphic(graphicsBitmapFill:GraphicsBitmapFill, context3D:Context3DProxy) : void
      {
         this.bitmapData = graphicsBitmapFill.bitmapData;
         this.repeat = graphicsBitmapFill.repeat;
         this.matrix2D = graphicsBitmapFill.matrix;
         this.texture = this.textureFactory.make(graphicsBitmapFill.bitmapData);
         this.offsetMatrix = GraphicsFillExtra.getOffsetUV(graphicsBitmapFill);
         this.vertexBufferCustom = GraphicsFillExtra.getVertexBuffer(graphicsBitmapFill);
         this.sinkLevel = GraphicsFillExtra.getSinkLevel(graphicsBitmapFill);
         if(this.sinkLevel != 0)
         {
            this.sinkOffset[1] = -this.sinkLevel;
            this.offsetMatrix = sinkOffset;
         }
         this.transform();
         var ct:ColorTransform = GraphicsFillExtra.getColorTransform(this.bitmapData);
         ctMult[0] = ct.redMultiplier;
         ctMult[1] = ct.greenMultiplier;
         ctMult[2] = ct.blueMultiplier;
         ctMult[3] = ct.alphaMultiplier;
         ctOffset[0] = ct.redOffset / 0xFF;
         ctOffset[1] = ct.greenOffset / 0xFF;
         ctOffset[2] = ct.blueOffset / 0xFF;
         ctOffset[3] = ct.alphaOffset / 0xFF;
         var c3d:Context3D = context3D.GetContext3D();
         c3d.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 2, ctMult);
         c3d.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 3, ctOffset);
      }
      
      /**
       * Batched radial shadows (object / projectile GraphicsGradientFills). Consecutive shadows in
       * a frame form one cluster drawn with a single drawTriangles; per-shadow colour/alpha travel
       * in the vertices instead of per-shadow constant uploads. Mirrors the software fill:
       * colors[0] at alphas[0] in the centre fading linearly to alphas[last] at the ellipse
       * inscribed in the gradient box (spread = pad). width / height are the half back-buffer
       * extents in world-scaled pixels (NDC divisor); ndcX / ndcY the NDC translation.
       * Returns false when the cluster buffer is full; the caller flushes and retries.
       */
      public function shadowBatchBegin(c3d:Context3D) : void
      {
         if(this.shadowData == null)
         {
            this.shadowData = new Vector.<Number>(SHADOW_CAP * 4 * SHADOW_FLOATS, true);
            this.shadowVBs = new Vector.<VertexBuffer3D>(SHADOW_RING, true);
            for(var i:int = 0; i < SHADOW_RING; i++)
            {
               this.shadowVBs[i] = c3d.createVertexBuffer(SHADOW_CAP * 4, SHADOW_FLOATS, Context3DBufferUsage.DYNAMIC_DRAW);
               // Stage3D rejects draws from a buffer that has never been filled end to end
               // ("Stream 0 is invalid", silent with error checking off). One full upload at
               // creation (zeros) makes the per-frame partial uploads in shadowBatchDraw valid.
               this.shadowVBs[i].uploadFromVector(this.shadowData, 0, SHADOW_CAP * 4);
            }
            this.shadowIB = c3d.createIndexBuffer(SHADOW_CAP * 6);
            var idx:Vector.<uint> = new Vector.<uint>(SHADOW_CAP * 6, true);
            var p:int = 0;
            var v:uint = 0;
            for(var q:int = 0; q < SHADOW_CAP; q++)
            {
               v = q * 4;
               idx[p++] = v;
               idx[p++] = v + 1;
               idx[p++] = v + 2;
               idx[p++] = v + 2;
               idx[p++] = v + 1;
               idx[p++] = v + 3;
            }
            this.shadowIB.uploadFromVector(idx, 0, SHADOW_CAP * 6);
         }
         this.shadowVB = this.shadowVBs[this.frame % SHADOW_RING];
         this.shadowQuads = 0;
      }

      public function get shadowBatchCount() : int
      {
         return this.shadowQuads;
      }

      public function shadowBatchQuad(fill:GraphicsGradientFill, halfW:Number, halfH:Number, ndcX:Number, ndcY:Number) : Boolean
      {
         if(this.shadowQuads >= SHADOW_CAP)
         {
            return false;
         }
         var m:Matrix = fill.matrix;
         var color:uint = 0;
         var alphaCenter:Number = 1;
         var alphaEdge:Number = 0;
         if(fill.colors != null && fill.colors.length > 0)
         {
            color = uint(fill.colors[0]);
         }
         if(fill.alphas != null && fill.alphas.length > 0)
         {
            alphaCenter = Number(fill.alphas[0]);
            alphaEdge = Number(fill.alphas[fill.alphas.length - 1]);
         }
         var r:Number = ((color >> 16) & 255) / 255;
         var g:Number = ((color >> 8) & 255) / 255;
         var b:Number = (color & 255) / 255;
         // Same maths as the old shadowTransform + NDC translation, evaluated per corner.
         var k:Number = GRADIENT_BOX_SIZE;
         var r0:Number = m.a * k / halfW;
         var r1:Number = -m.b * k / halfH;
         var r4:Number = -m.c * k / halfW;
         var r5:Number = m.d * k / halfH;
         var r12:Number = m.tx / halfW + ndcX;
         var r13:Number = -m.ty / halfH + ndcY;
         var d:Vector.<Number> = this.shadowData;
         var p:int = this.shadowQuads * 4 * SHADOW_FLOATS;
         // Corner order matches the index buffer: (-.5,.5), (.5,.5), (-.5,-.5), (.5,-.5).
         // va0 = (x, y, 0, alphaEdge), va1 = (u, v), va2 = (r, g, b, alphaCenter).
         d[p] = -0.5 * r0 + 0.5 * r4 + r12;  d[p + 1] = -0.5 * r1 + 0.5 * r5 + r13;  d[p + 2] = 0;  d[p + 3] = alphaEdge;  d[p + 4] = 0;  d[p + 5] = 1;
         d[p + 6] = r;  d[p + 7] = g;  d[p + 8] = b;  d[p + 9] = alphaCenter;
         d[p + 10] = 0.5 * r0 + 0.5 * r4 + r12;  d[p + 11] = 0.5 * r1 + 0.5 * r5 + r13;  d[p + 12] = 0;  d[p + 13] = alphaEdge;  d[p + 14] = 1;  d[p + 15] = 1;
         d[p + 16] = r;  d[p + 17] = g;  d[p + 18] = b;  d[p + 19] = alphaCenter;
         d[p + 20] = -0.5 * r0 - 0.5 * r4 + r12;  d[p + 21] = -0.5 * r1 - 0.5 * r5 + r13;  d[p + 22] = 0;  d[p + 23] = alphaEdge;  d[p + 24] = 0;  d[p + 25] = 0;
         d[p + 26] = r;  d[p + 27] = g;  d[p + 28] = b;  d[p + 29] = alphaCenter;
         d[p + 30] = 0.5 * r0 - 0.5 * r4 + r12;  d[p + 31] = 0.5 * r1 - 0.5 * r5 + r13;  d[p + 32] = 0;  d[p + 33] = alphaEdge;  d[p + 34] = 1;  d[p + 35] = 0;
         d[p + 36] = r;  d[p + 37] = g;  d[p + 38] = b;  d[p + 39] = alphaCenter;
         this.shadowQuads++;
         return true;
      }

      /**
       * Uploads the accumulated cluster and draws it with one drawTriangles. The caller binds the
       * batch program and fc4 helpers once per cluster; positions are already NDC so vc0 is set to
       * identity here. Resets the count so the buffer can be reused after an overflow flush.
       */
      public function shadowBatchDraw(c3d:Context3D) : void
      {
         if(this.shadowQuads <= 0)
         {
            return;
         }
         this.shadowVB.uploadFromVector(this.shadowData, 0, this.shadowQuads * 4);
         c3d.setVertexBufferAt(0, this.shadowVB, 0, Context3DVertexBufferFormat.FLOAT_4);
         c3d.setVertexBufferAt(1, this.shadowVB, 4, Context3DVertexBufferFormat.FLOAT_2);
         c3d.setVertexBufferAt(2, this.shadowVB, 6, Context3DVertexBufferFormat.FLOAT_4);
         c3d.setTextureAt(0, null);
         c3d.setProgramConstantsFromMatrix(Context3DProgramType.VERTEX, 0, IDENTITY, true);
         FrameProfiler.frameDrawCalls++;
         c3d.drawTriangles(this.shadowIB, 0, this.shadowQuads * 2);
         this.shadowQuads = 0;
      }
      
      private function transform() : void
      {
         this.transformWith(Math.ceil(this.texture.getWidth()),Math.ceil(this.texture.getHeight()));
      }

      // 2D fill matrix -> matrix3D for the unit quad. texW/texH are the (pow2) texture dimensions.
      private function transformWith(texW:Number, texH:Number) : void
      {
         this.matrix3D.identity();
         this.matrix3D.copyRawDataTo(rawMatrix3D);
         rawMatrix3D[4] = -this.matrix2D.c;
         rawMatrix3D[1] = -this.matrix2D.b;
         rawMatrix3D[0] = this.matrix2D.a;
         rawMatrix3D[5] = this.matrix2D.d;
         rawMatrix3D[12] = this.matrix2D.tx;
         rawMatrix3D[13] = -this.matrix2D.ty;
         this.matrix3D.copyRawDataFrom(rawMatrix3D) ;
         this.matrix3D.prependScale(texW,texH,1);
         this.matrix3D.prependTranslation(0.5,-0.5,0);
      }
      
      public function render(c3dProxy:Context3DProxy) : void
      {
         c3dProxy.setProgram(Program3DFactory.getInstance().getProgram(c3dProxy,this.repeat));
         c3dProxy.setTextureAt(0,this.texture);
         var c3d:Context3D = c3dProxy.GetContext3D();
         if(this.vertexBufferCustom != null)
         {
            c3d.setVertexBufferAt(0,this.vertexBufferCustom,0,Context3DVertexBufferFormat.FLOAT_3);
            c3d.setVertexBufferAt(1,this.vertexBufferCustom,3,Context3DVertexBufferFormat.FLOAT_2);
            c3d.setProgramConstantsFromVector(Context3DProgramType.VERTEX,4,this.offsetMatrix);
            c3d.setVertexBufferAt(2,null,6,Context3DVertexBufferFormat.FLOAT_2);
            c3dProxy.drawTriangles(this.indexBuffer);
         }
         else
         {
            c3dProxy.setVertexBufferAt(0,this.vertexBuffer,0,Context3DVertexBufferFormat.FLOAT_3);
            c3dProxy.setVertexBufferAt(1,this.vertexBuffer,3,Context3DVertexBufferFormat.FLOAT_2);
            c3d.setProgramConstantsFromVector(Context3DProgramType.VERTEX,4,this.offsetMatrix);
            c3d.setVertexBufferAt(2,null,6,Context3DVertexBufferFormat.FLOAT_2);
            c3dProxy.drawTriangles(this.indexBuffer);
         }
      }
      
      public function getMatrix3D() : Matrix3D
      {
         return this.matrix3D;
      }
   }
}
