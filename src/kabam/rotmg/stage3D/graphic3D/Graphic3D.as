package kabam.rotmg.stage3D.graphic3D
{
   import com.company.assembleegameclient.util.FrameProfiler;
   import flash.display.BitmapData;
   import flash.display.GraphicsBitmapFill;
   import flash.display.GraphicsGradientFill;
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
   import kabam.rotmg.stage3D.GraphicsFillExtra;
   import kabam.rotmg.stage3D.proxies.Context3DProxy;
   import kabam.rotmg.stage3D.proxies.IndexBuffer3DProxy;
   import kabam.rotmg.stage3D.proxies.TextureProxy;
   import kabam.rotmg.stage3D.proxies.VertexBuffer3DProxy;
   
   public class Graphic3D
   {
      // Unit quad for gradient (shadow) fills: xyz position, uv. Scaled to the gradient box in shadowTransform.
      private static const gradientVertex:Vector.<Number> = Vector.<Number>(
              [-0.5, 0.5, 0, 0, 1,
                0.5, 0.5, 0, 1, 1,
               -0.5, -0.5, 0, 0, 0,
                0.5, -0.5, 0, 1, 0]);
      private static const indices:Vector.<uint> = Vector.<uint>([0,1,2,2,1,3]);
      
      // Matrix.createGradientBox maps a 1638.4-unit gradient square onto the box (a = width / 1638.4).
      private static const GRADIENT_BOX_SIZE:Number = 1638.4;

      // Positions of the shared sprite quad (VertexBufferFactory), in the same vertex order.
      private static const UNIT_QUAD_XYZ:Vector.<Number> = new <Number>[-0.5,0.5,0, 0.5,0.5,0, -0.5,-0.5,0, 0.5,-0.5,0];
      private static const IDENTITY:Matrix3D = new Matrix3D();

      // Deferred draw commands recorded by the batch pass (see batchBegin).
      public static const CMD_RUN:int = 0;      // arg = run index
      public static const CMD_QUAD:int = 1;     // arg = graphicsData index; per-quad drawQuad path
      public static const CMD_SHADOW:int = 2;   // arg = graphicsData index
      public static const CMD_MODEL:int = 3;    // next 3D model

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
      private var shadowMatrix2D:Matrix;
      private var sinkLevel:Number = 0;
      private var offsetMatrix:Vector.<Number>;
      private var vertexBufferCustom:VertexBuffer3D;
      private var gradientVB:VertexBuffer3D;
      private var gradientIB:IndexBuffer3D;
      private var repeat:Boolean;

      private var sinkOffset:Vector.<Number>;
      private var ctMult:Vector.<Number>;
      private var ctOffset:Vector.<Number>;
      private var rawMatrix3D:Vector.<Number>;
      private var gradientColor:Vector.<Number>;
      private var gradientAlpha:Vector.<Number>;

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
      private var batchQuads:int = 0;
      private var batchOverflow:Boolean = false;
      private var xformed:Vector.<Number>;
      private var offsetScratch:Vector.<Number>;
      public var cmdType:Vector.<int>;
      public var cmdArg:Vector.<int>;
      public var cmdCount:int = 0;
      private var runFirstQuad:Vector.<int>;
      private var runQuadCount:Vector.<int>;
      private var runTexture:Vector.<TextureBase>;
      private var runRepeat:Vector.<int>;
      private var runConst:Vector.<Number>;   // 12 per run: uv offset (4) + colour transform (8)
      private var runCount:int = 0;
      private var runOpen:Boolean = false;
      
      public function Graphic3D()
      {
         this.matrix3D = new Matrix3D();
         this.gradientColor = new Vector.<Number>(4, true);
         this.gradientAlpha = new Vector.<Number>(4, true);
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
         this.cmdCount = 0;
         this.runCount = 0;
         this.runOpen = false;
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
      }

      /**
       * Record a sprite quad. Returns false if the quad cannot be batched (custom vertex buffer,
       * or the batch is full) and must be drawn via drawQuad at this point in the order.
       */
      public function batchQuad(fill:GraphicsBitmapFill) : Boolean
      {
         if(GraphicsFillExtra.getVertexBuffer(fill) != null)
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
         // uv offset (vc4): animated tiles / water sink. The offset relies on the sampler
         // clamping to the sprite's own edge, so anything offset (or repeating) must keep its
         // individual texture; only plain quads can share an atlas page.
         var offset:Vector.<Number> = GraphicsFillExtra.getOffsetUV(fill);
         var sink:Number = GraphicsFillExtra.getSinkLevel(fill);
         if(sink != 0)
         {
            this.sinkOffset[1] = -sink;
            offset = this.sinkOffset;
         }
         var plain:Boolean = !fill.repeat && offset[0] == 0 && offset[1] == 0 && offset[2] == 0 && offset[3] == 0;
         var entry:AtlasEntry = plain ? this.textureFactory.getAtlas().get(bmd,this.frame) : null;
         if(entry != null)
         {
            texBase = entry.page.texture;
            w = entry.w;
            h = entry.h;
            u0 = entry.u0;
            v0 = entry.v0;
            u1 = entry.u1;
            v1 = entry.v1;
         }
         else
         {
            var tex:TextureProxy = this.textureFactory.make(bmd);
            if(tex == null)
            {
               return true;   // drawQuad draws nothing for this either
            }
            texBase = tex.getTexture();
            w = tex.getWidth();
            h = tex.getHeight();
         }

         // --- vertex transform: same Matrix3D chain as drawQuad ---
         this.matrix2D = fill.matrix;
         this.transformWith(w,h);
         var f:Matrix3D = this.finalTransform;
         f.identity();
         f.append(this.matrix3D);
         f.appendScale(1 / this.bHalfW,1 / this.bHalfH,1);
         f.appendTranslation(this.bNdcX,this.bNdcY,0);
         var out:Vector.<Number> = this.xformed;
         f.transformVectors(UNIT_QUAD_XYZ,out);

         // --- run state ---
         var ct:ColorTransform = GraphicsFillExtra.getColorTransform(bmd);
         var repeatIdx:int = fill.repeat ? 1 : 0;
         var rc:Vector.<Number> = this.runConst;
         var r:int = this.runCount - 1;
         var k:int = r * 12;
         var newRun:Boolean = !this.runOpen || this.runTexture[r] != texBase || this.runRepeat[r] != repeatIdx
            || rc[k] != offset[0] || rc[k + 1] != offset[1] || rc[k + 2] != offset[2] || rc[k + 3] != offset[3]
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
            rc[k] = offset[0];
            rc[k + 1] = offset[1];
            rc[k + 2] = offset[2];
            rc[k + 3] = offset[3];
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

      /** Record a non-batched item (shadow, 3D model, per-quad fallback); closes the open run. */
      public function batchMark(type:int, arg:int) : void
      {
         this.runOpen = false;
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

         // --- uv offset (vc4): animated tiles / water sink ---
         var offset:Vector.<Number> = GraphicsFillExtra.getOffsetUV(fill);
         var sink:Number = GraphicsFillExtra.getSinkLevel(fill);
         if(sink != 0)
         {
            this.sinkOffset[1] = -sink;
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
       * Prepares a radial GraphicsGradientFill (object / projectile shadows) for the GPU shadow program.
       * Mirrors the software fill: colors[0] at alphas[0] in the centre fading linearly to alphas[last]
       * at the ellipse inscribed in the gradient box (spread = pad, so alpha stays at alphas[last] outside).
       * Uploads fc5 = (r, g, b, 0) and fc6 = (alphaCenter, alphaEdge, 0, 0).
       * width / height are the half back-buffer extents in world-scaled pixels (NDC divisor).
       */
      public function setGradientFill(gradientFill:GraphicsGradientFill, context3D:Context3DProxy, width:Number, height:Number) : void
      {
         this.shadowMatrix2D = gradientFill.matrix;
         var c3d:Context3D = context3D.GetContext3D();
         if(this.gradientVB == null || this.gradientIB == null)
         {
            this.gradientVB = c3d.createVertexBuffer(4,5);
            this.gradientVB.uploadFromVector(gradientVertex,0,4);
            this.gradientIB = c3d.createIndexBuffer(6);
            this.gradientIB.uploadFromVector(indices,0,6);
         }
         var color:uint = 0;
         var alphaCenter:Number = 1;
         var alphaEdge:Number = 0;
         if(gradientFill.colors != null && gradientFill.colors.length > 0)
         {
            color = uint(gradientFill.colors[0]);
         }
         if(gradientFill.alphas != null && gradientFill.alphas.length > 0)
         {
            alphaCenter = Number(gradientFill.alphas[0]);
            alphaEdge = Number(gradientFill.alphas[gradientFill.alphas.length - 1]);
         }
         this.gradientColor[0] = ((color >> 16) & 255) / 255;
         this.gradientColor[1] = ((color >> 8) & 255) / 255;
         this.gradientColor[2] = (color & 255) / 255;
         this.gradientColor[3] = 0;
         this.gradientAlpha[0] = alphaCenter;
         this.gradientAlpha[1] = alphaEdge;
         c3d.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT,5,this.gradientColor);
         c3d.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT,6,this.gradientAlpha);
         this.shadowTransform(width,height);
      }
      
      // Unit quad -> gradient box in NDC. The quad must cover the full box (2w x 2h screen px) so the
      // shader's normalised radius hits 1 exactly on the inscribed ellipse, as the software gradient does.
      private function shadowTransform(width:Number, height:Number) : void
      {
         this.matrix3D.identity();
         var raw:Vector.<Number> = this.matrix3D.rawData;
         raw[4] = -this.shadowMatrix2D.c * GRADIENT_BOX_SIZE / width;
         raw[1] = -this.shadowMatrix2D.b * GRADIENT_BOX_SIZE / height;
         raw[0] = this.shadowMatrix2D.a * GRADIENT_BOX_SIZE / width;
         raw[5] = this.shadowMatrix2D.d * GRADIENT_BOX_SIZE / height;
         raw[12] = this.shadowMatrix2D.tx / width;
         raw[13] = -this.shadowMatrix2D.ty / height;
         this.matrix3D.rawData = raw;
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
      
      public function renderShadow(c3dProxy:Context3DProxy) : void
      {
         var c3d:Context3D = c3dProxy.GetContext3D();
         c3d.setVertexBufferAt(0,this.gradientVB,0,Context3DVertexBufferFormat.FLOAT_3);
         c3d.setVertexBufferAt(1,this.gradientVB,3,Context3DVertexBufferFormat.FLOAT_2);
         c3d.setVertexBufferAt(2,null);
         c3d.setTextureAt(0,null);
         FrameProfiler.frameDrawCalls++;
         c3d.drawTriangles(this.gradientIB);
      }
      
      public function getMatrix3D() : Matrix3D
      {
         return this.matrix3D;
      }
   }
}
