package kabam.rotmg.stage3D.graphic3D
{
   import flash.display.BitmapData;
   import flash.display3D.Context3D;
   import flash.display3D.Context3DBlendFactor;
   import flash.display3D.Context3DProgramType;
   import flash.display3D.Context3DTextureFormat;
   import flash.display3D.Context3DTriangleFace;
   import flash.display3D.Context3DVertexBufferFormat;
   import flash.display3D.IndexBuffer3D;
   import flash.display3D.Program3D;
   import flash.display3D.VertexBuffer3D;
   import flash.display3D.textures.Texture;
   import flash.geom.Matrix3D;
   import flash.geom.Point;
   import flash.geom.Rectangle;
   import flash.utils.Dictionary;

   /**
    * Packs sprite BitmapDatas into large texture pages so consecutive sprite quads can share one
    * texture binding (and therefore one draw call).
    *
    * Each sprite gets a slot of its power-of-2 padded size, exactly the texture it would have had
    * as an individual texture (TextureFactory.make), so the quad geometry and uv range are the
    * same as before; only the uv origin/scale differ. Slots are separated by a 1-texel gap.
    * Scrolling/repeat sprites get tilable slots holding a 2x2 replication, so any fractional
    * scroll offset samples continuous content with the clamp sampler (see get(tilable)).
    *
    * Two ways of getting sprites into a page (USE_RTT):
    *  - false: each page has a CPU-side BitmapData; new sprites are copyPixels'd into it and the
    *    whole page is re-uploaded with uploadFromBitmapData at most once per frame it changed.
    *    Simple and identical to how individual textures were uploaded; costs a 16 MB upload on
    *    frames where new sprites appear.
    *  - true: the sprite is uploaded to a temporary texture and blitted into the page with
    *    render-to-texture (nearest sampling at texel centres, blending off). No page re-upload.
    *
    * GPU resources retired during a frame (temp textures / bitmaps) are disposed at the start
    * of the next frame, after present(), so deferred Stage3D commands never see freed data.
    *
    * Eviction is per page: when no page has room and the page limit is reached, the page that
    * was least recently used *and not used this frame* is reset. Entries on a reset page become
    * stale (generation mismatch) and are re-added on next use.
    */
   public class SpriteAtlas
   {
      public static const PAGE_SIZE:int = 2048;
      public static const MAX_PAGES:int = 8;
      // Sprites larger than this (after pow2 padding) keep individual textures.
      public static const MAX_SLOT:int = 512;
      private static const HALF:Number = PAGE_SIZE / 2;
      // Fill pages with render-to-texture blits instead of CPU-side page bitmaps + re-upload.
      public static const USE_RTT:Boolean = false;
      // RTT only: set to true if sprites come out vertically mirrored.
      private static const FLIP_Y:Boolean = false;

      private static const IDENTITY:Matrix3D = new Matrix3D();
      private static const ONES:Vector.<Number> = new <Number>[1,1,1,1];
      private static const ZEROS:Vector.<Number> = new <Number>[0,0,0,0];
      private static const BLIT_INDICES:Vector.<uint> = new <uint>[0,1,2,2,1,3];

      private var context:Context3D;
      private var pages:Vector.<AtlasPage> = new Vector.<AtlasPage>();
      // BitmapData -> AtlasEntry. Weak keys so disposed sprites don't pin their BitmapData.
      private var entries:Dictionary = new Dictionary(true);
      // Same, for tilable (2x2) slots used by scrolling/repeat sprites. A sprite used both
      // ways occupies one slot of each kind; the duplication is one-time and small.
      private var tilableEntries:Dictionary = new Dictionary(true);
      // RTT mode: blits queued for flush().
      private var pendingSrc:Vector.<Texture> = new Vector.<Texture>();
      private var pendingEntry:Vector.<AtlasEntry> = new Vector.<AtlasEntry>();
      // CPU mode: pages whose bitmap changed this frame.
      private var dirtyPages:Vector.<AtlasPage> = new Vector.<AtlasPage>();
      // Disposed at the start of the next frame.
      private var retiredTextures:Vector.<Texture> = new Vector.<Texture>();
      private var retiredBitmaps:Vector.<BitmapData> = new Vector.<BitmapData>();
      private var blitVB:VertexBuffer3D;
      private var blitIB:IndexBuffer3D;
      private var blitVerts:Vector.<Number> = new Vector.<Number>(20,true);
      private var dest:Point = new Point();
      private var srcRect:Rectangle = new Rectangle();
      private var pageRect:Rectangle = new Rectangle(0,0,PAGE_SIZE,PAGE_SIZE);

      public var pageCount:int = 0;
      public var evictions:int = 0;
      public var uploads:int = 0;   // page uploads (CPU mode) or blits (RTT mode), lifetime

      public function SpriteAtlas(context:Context3D)
      {
         super();
         this.context = context;
      }

      /** Call once per frame before any get(): frees resources retired in the previous frame. */
      public function beginFrame() : void
      {
         var t:Texture = null;
         var b:BitmapData = null;
         for each(t in this.retiredTextures)
         {
            t.dispose();
         }
         this.retiredTextures.length = 0;
         for each(b in this.retiredBitmaps)
         {
            b.dispose();
         }
         this.retiredBitmaps.length = 0;
      }

      public function dispose() : void
      {
         var p:AtlasPage = null;
         var t:Texture = null;
         this.beginFrame();
         for each(p in this.pages)
         {
            p.texture.dispose();
            if(p.bitmap != null)
            {
               p.bitmap.dispose();
            }
         }
         this.pages.length = 0;
         this.pageCount = 0;
         for each(t in this.pendingSrc)
         {
            t.dispose();
         }
         this.pendingSrc.length = 0;
         this.pendingEntry.length = 0;
         this.dirtyPages.length = 0;
         this.entries = new Dictionary(true);
         this.tilableEntries = new Dictionary(true);
         if(this.blitVB != null)
         {
            this.blitVB.dispose();
            this.blitVB = null;
         }
         if(this.blitIB != null)
         {
            this.blitIB.dispose();
            this.blitIB = null;
         }
      }

      public function hasPending() : Boolean
      {
         return this.pendingSrc.length > 0 || this.dirtyPages.length > 0;
      }

      /**
       * Returns the atlas entry for a sprite, queueing an upload if it is new. Returns null if
       * the sprite is too large or no page has room this frame (caller falls back to an
       * individual texture).
       *
       * Tilable entries hold a 2x2 replication for scrolling/repeat sprites (see
       * Graphic3D.batchQuad): any fractional offset then samples continuous content with
       * the clamp sampler, so these quads batch exactly like plain ones. The RTT blit path
       * does not replicate; tilable requests fall back to individual textures there.
       */
      public function get(bmd:BitmapData, frame:int, tilable:Boolean = false) : AtlasEntry
      {
         var dict:Dictionary = tilable ? this.tilableEntries : this.entries;
         var e:AtlasEntry = dict[bmd];
         if(e != null && e.generation == e.page.generation)
         {
            e.page.lastUsed = frame;
            return e;
         }
         var w:int = nextPow2(bmd.width);
         var h:int = nextPow2(bmd.height);
         if(w > MAX_SLOT || h > MAX_SLOT)
         {
            return null;
         }
         if(tilable && USE_RTT)
         {
            return null;
         }
         e = this.allocate(w,h,frame,tilable);
         if(e == null)
         {
            return null;
         }
         if(tilable)
         {
            // 2x2 replication; the outer 1-texel border replicates the block edge so
            // linear taps at the block boundary behave like clamp-to-edge.
            var tpb:BitmapData = e.page.bitmap;
            this.dest.x = e.x;
            this.dest.y = e.y;
            tpb.copyPixels(bmd,bmd.rect,this.dest);
            this.dest.x = e.x + w;
            this.dest.y = e.y;
            tpb.copyPixels(bmd,bmd.rect,this.dest);
            this.dest.x = e.x;
            this.dest.y = e.y + h;
            tpb.copyPixels(bmd,bmd.rect,this.dest);
            this.dest.x = e.x + w;
            this.dest.y = e.y + h;
            tpb.copyPixels(bmd,bmd.rect,this.dest);
            this.copyRegion(tpb,e.x,e.y,2 * w,1,e.x,e.y - 1);                 // top row
            this.copyRegion(tpb,e.x,e.y + 2 * h - 1,2 * w,1,e.x,e.y + 2 * h); // bottom row
            this.copyRegion(tpb,e.x,e.y - 1,1,2 * h + 2,e.x - 1,e.y - 1);     // left column incl. corners
            this.copyRegion(tpb,e.x + 2 * w - 1,e.y - 1,1,2 * h + 2,e.x + 2 * w,e.y - 1); // right column
            this.dest.x = 0;
            this.dest.y = 0;
            if(!e.page.dirty)
            {
               e.page.dirty = true;
               this.dirtyPages.push(e.page);
            }
            dict[bmd] = e;
            return e;
         }
         if(USE_RTT)
         {
            // Same padded copy TextureFactory.make uploads for an individual texture.
            var padded:BitmapData = new BitmapData(w,h,true,0);
            padded.copyPixels(bmd,bmd.rect,this.dest);   // dest is (0,0) here
            var src:Texture = this.context.createTexture(w,h,Context3DTextureFormat.BGRA,false);
            src.uploadFromBitmapData(padded);
            this.retiredBitmaps.push(padded);
            this.pendingSrc.push(src);
            this.pendingEntry.push(e);
         }
         else
         {
            // Slot area is already transparent (page cleared on create/reset, slots never overlap).
            var pb:BitmapData = e.page.bitmap;
            this.dest.x = e.x;
            this.dest.y = e.y;
            pb.copyPixels(bmd,bmd.rect,this.dest);
            // Replicate the pow2-padded slot's edge texels into the 1-texel border: clamp-to-edge.
            this.copyRegion(pb,e.x,e.y,1,h,e.x - 1,e.y);                     // left column
            this.copyRegion(pb,e.x + w - 1,e.y,1,h,e.x + w,e.y);             // right column
            this.copyRegion(pb,e.x - 1,e.y,w + 2,1,e.x - 1,e.y - 1);         // top row incl. corners
            this.copyRegion(pb,e.x - 1,e.y + h - 1,w + 2,1,e.x - 1,e.y + h); // bottom row incl. corners
            this.dest.x = 0;
            this.dest.y = 0;
            if(!e.page.dirty)
            {
               e.page.dirty = true;
               this.dirtyPages.push(e.page);
            }
         }
         dict[bmd] = e;
         return e;
      }

      private function copyRegion(pb:BitmapData, sx:int, sy:int, sw:int, sh:int, dx:int, dy:int) : void
      {
         this.srcRect.setTo(sx,sy,sw,sh);
         this.dest.x = dx;
         this.dest.y = dy;
         pb.copyPixels(pb,this.srcRect,this.dest);
      }

      private function allocate(w:int, h:int, frame:int, tilable:Boolean) : AtlasEntry
      {
         var p:AtlasPage = null;
         var e:AtlasEntry = null;
         var n:int = this.pages.length;
         for(var i:int = 0; i < n; i++)
         {
            p = this.pages[i];
            e = tilable ? p.allocTiled(w,h) : p.alloc(w,h);
            if(e != null)
            {
               p.lastUsed = frame;
               return e;
            }
         }
         if(n < MAX_PAGES)
         {
            p = new AtlasPage(this.context.createTexture(PAGE_SIZE,PAGE_SIZE,Context3DTextureFormat.BGRA,USE_RTT));
            if(!USE_RTT)
            {
               p.bitmap = new BitmapData(PAGE_SIZE,PAGE_SIZE,true,0);
            }
            this.pages.push(p);
            this.pageCount = this.pages.length;
            p.lastUsed = frame;
            return tilable ? p.allocTiled(w,h) : p.alloc(w,h);
         }
         // Evict the least recently used page that is not referenced by this frame's draws.
         var victim:AtlasPage = null;
         for(i = 0; i < n; i++)
         {
            p = this.pages[i];
            if(p.lastUsed < frame && (victim == null || p.lastUsed < victim.lastUsed))
            {
               victim = p;
            }
         }
         if(victim == null)
         {
            return null;
         }
         victim.reset();
         if(victim.bitmap != null)
         {
            victim.bitmap.fillRect(this.pageRect,0);
         }
         victim.lastUsed = frame;
         this.evictions++;
         return tilable ? victim.allocTiled(w,h) : victim.alloc(w,h);
      }

      /**
       * Pushes this frame's new sprites to the GPU. In CPU mode this uploads each dirty page; the
       * render target is untouched. In RTT mode it blits with render-to-texture and leaves the
       * render target on the last page: the caller must reset it (setRenderToBackBuffer /
       * setRenderToTexture) and treat all program/texture/vertex-buffer state as unknown
       * afterwards. Blend factors are restored to the scene's SOURCE_ALPHA / ONE_MINUS_SOURCE_ALPHA.
       */
      public function flush(c3d:Context3D, program:Program3D) : void
      {
         var p:AtlasPage = null;
         var n:int = this.dirtyPages.length;
         if(n > 0)
         {
            for(var di:int = 0; di < n; di++)
            {
               p = this.dirtyPages[di];
               p.texture.uploadFromBitmapData(p.bitmap);
               p.dirty = false;
               p.needsClear = false;
               this.uploads++;
            }
            this.dirtyPages.length = 0;
         }
         n = this.pendingSrc.length;
         if(n == 0)
         {
            return;
         }
         if(this.blitVB == null)
         {
            this.blitVB = c3d.createVertexBuffer(4,5);
            this.blitIB = c3d.createIndexBuffer(6);
            this.blitIB.uploadFromVector(BLIT_INDICES,0,6);
         }
         var current:AtlasPage = null;
         var e:AtlasEntry = null;
         var src:Texture = null;
         // A page may still be bound as a sampler from the previous frame.
         c3d.setTextureAt(0,null);
         c3d.setCulling(Context3DTriangleFace.NONE);
         c3d.setProgram(program);
         c3d.setProgramConstantsFromMatrix(Context3DProgramType.VERTEX,0,IDENTITY,true);
         c3d.setProgramConstantsFromVector(Context3DProgramType.VERTEX,4,ZEROS);
         c3d.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT,2,ONES);
         c3d.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT,3,ZEROS);
         c3d.setBlendFactors(Context3DBlendFactor.ONE,Context3DBlendFactor.ZERO);
         c3d.setVertexBufferAt(0,this.blitVB,0,Context3DVertexBufferFormat.FLOAT_3);
         c3d.setVertexBufferAt(1,this.blitVB,3,Context3DVertexBufferFormat.FLOAT_2);
         c3d.setVertexBufferAt(2,null);
         for(var i:int = 0; i < n; i++)
         {
            e = this.pendingEntry[i];
            src = this.pendingSrc[i];
            if(e.page != current)
            {
               current = e.page;
               c3d.setRenderToTexture(current.texture,false,0,0);
               if(current.needsClear)
               {
                  c3d.clear(0,0,0,0);
                  current.needsClear = false;
               }
            }
            c3d.setTextureAt(0,src);
            // Slot rectangle, then the four 1-texel border strips with uvs pinned to the edge
            // (clamp sampling of the source replicates its edge texels, incl. corners).
            this.blit(c3d,e.x,e.y,e.w,e.h,0,0,1,1);
            var vPad:Number = 1 / e.h;   // strips span h+2 texels: v runs -1/h .. 1+1/h so rows line up
            this.blit(c3d,e.x - 1,e.y - 1,1,e.h + 2,0,-vPad,0,1 + vPad);     // left
            this.blit(c3d,e.x + e.w,e.y - 1,1,e.h + 2,1,-vPad,1,1 + vPad);   // right
            this.blit(c3d,e.x,e.y - 1,e.w,1,0,0,1,0);                   // top
            this.blit(c3d,e.x,e.y + e.h,e.w,1,0,1,1,1);                 // bottom
            this.retiredTextures.push(src);
            this.uploads++;
         }
         this.pendingSrc.length = 0;
         this.pendingEntry.length = 0;
         c3d.setTextureAt(0,null);
         c3d.setBlendFactors(Context3DBlendFactor.SOURCE_ALPHA,Context3DBlendFactor.ONE_MINUS_SOURCE_ALPHA);
      }

      /** RTT mode: draw the bound source texture over page texels [x, x+w) x [y, y+h) with the given uvs. */
      private function blit(c3d:Context3D, x:int, y:int, w:int, h:int, u0:Number, v0:Number, u1:Number, v1:Number) : void
      {
         // Page NDC; texel edges land exactly on pixel edges.
         var x0:Number = x / HALF - 1;
         var x1:Number = (x + w) / HALF - 1;
         var y0:Number = 0;
         var y1:Number = 0;
         if(FLIP_Y)
         {
            y0 = y / HALF - 1;
            y1 = (y + h) / HALF - 1;
         }
         else
         {
            y0 = 1 - y / HALF;
            y1 = 1 - (y + h) / HALF;
         }
         var v:Vector.<Number> = this.blitVerts;
         v[0] = x0;  v[1] = y0;  v[2] = 0; v[3] = u0;  v[4] = v0;
         v[5] = x1;  v[6] = y0;  v[7] = 0; v[8] = u1;  v[9] = v0;
         v[10] = x0; v[11] = y1; v[12] = 0; v[13] = u0; v[14] = v1;
         v[15] = x1; v[16] = y1; v[17] = 0; v[18] = u1; v[19] = v1;
         this.blitVB.uploadFromVector(v,0,4);
         c3d.drawTriangles(this.blitIB);
      }

      private static function nextPow2(value:int) : int
      {
         value--;
         value = value | value >> 1;
         value = value | value >> 2;
         value = value | value >> 4;
         value = value | value >> 8;
         value = value | value >> 16;
         value++;
         return value;
      }
   }
}
