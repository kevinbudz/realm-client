package kabam.rotmg.stage3D
{
   import com.adobe.utils.AGALMiniAssembler;
   import com.company.assembleegameclient.engine3d.Lighting3D;
   import com.company.assembleegameclient.map.Camera;
   import com.company.assembleegameclient.parameters.Parameters;
   import com.company.assembleegameclient.util.FrameProfiler;
   import flash.display.GraphicsBitmapFill;
   import flash.display.GraphicsGradientFill;
   import flash.display.IGraphicsData;
   import flash.display.Stage3D;
   import flash.display.StageScaleMode;
   import flash.display3D.Context3D;
   import flash.display3D.Context3DProgramType;
   import flash.display3D.Context3DTextureFormat;
   import flash.display3D.Context3DTriangleFace;
   import flash.display3D.Context3DVertexBufferFormat;
   import flash.display3D.IndexBuffer3D;
   import flash.display3D.Program3D;
   import flash.display3D.VertexBuffer3D;
   import flash.display3D.textures.Texture;
   import flash.geom.Matrix3D;
   import flash.geom.Vector3D;
   import flash.utils.ByteArray;
   import kabam.rotmg.stage3D.Object3D.Object3DStage3D;
   import kabam.rotmg.stage3D.graphic3D.Graphic3D;
   import kabam.rotmg.stage3D.graphic3D.TextureFactory;
   import kabam.rotmg.stage3D.proxies.Context3DProxy;
   import org.swiftsuspenders.Injector;
   
   public class Renderer
   {
      
      public static const STAGE3D_FILTER_PAUSE:uint = 1;
      
      public static const STAGE3D_FILTER_BLIND:uint = 2;
      
      public static const STAGE3D_FILTER_DRUNK:uint = 3;
      
      public static var inGame:Boolean;
      
      private static const POST_FILTER_VERTEX_CONSTANTS:Vector.<Number> = new <Number>[1,2,0,0];
      
      private static const GRAYSCALE_FRAGMENT_CONSTANTS:Vector.<Number> = new <Number>[0.3,0.59,0.11,0];
      
      private static const BLIND_FRAGMENT_CONSTANTS:Vector.<Number> = new <Number>[0.05,0.05,0.05,0];
      
      private static const POST_FILTER_POSITIONS:Vector.<Number> = new <Number>[-1,1,0,0,1,1,1,0,1,-1,1,1,-1,-1,0,1];
      
      private static const POST_FILTER_TRIS:Vector.<uint> = new <uint>[0,2,3,0,1,2];
      
      // fc4 for the shadow program: (0.5 uv centre, 2 = 1/half-extent, 1, 0)
      private static const SHADOW_FRAGMENT_CONSTANTS:Vector.<Number> = new <Number>[0.5,2,1,0];
       
      
      [Inject]
      public var context3D:Context3DProxy;
      
      [Inject]
      public var textureFactory:TextureFactory;
      
      [Inject]
      public var injector:Injector;
      
      private var tX:Number;
      
      private var tY:Number;
      
      public var program2:Program3D;
      
      private var postProcessingProgram_:Program3D;
      
      private var blurPostProcessing_:Program3D;
      
      private var shadowProgram_:Program3D;
      
      private var graphic3D_:Graphic3D;
      
      private static const IDENTITY_MATRIX:Matrix3D = new Matrix3D();
      
      private var finalTransform_:Matrix3D = new Matrix3D();
      
      private var stageWidth:Number = 600;
      
      private var stageHeight:Number = 600;
      
      private var sceneTexture_:Texture;
      
      private var blurFactor:Number = 0.01;
      
      private var postFilterVertexBuffer_:VertexBuffer3D;
      
      private var postFilterIndexBuffer_:IndexBuffer3D;
      
      protected var _vertexShader:String;
      
      protected var _fragmentShader:String;
      
      protected var _solidFragmentShader:String;
      
      private var solidProgram_:Program3D;
      
      // Lighting3D.LIGHT_VECTOR = normalize(1, 3, 2), world space
      private static const MODEL_LIGHT_CONSTANTS:Vector.<Number> = createLightConstants();
      
      // (1 - ambient, ambient, 0, 1) with ambient = 0.75 (ObjectFace3D.computeLighting)
      private static const MODEL_SHADE_CONSTANTS:Vector.<Number> = new <Number>[0.25,0.75,0,1];
      
      private static function createLightConstants() : Vector.<Number>
      {
         var l:Vector3D = Lighting3D.LIGHT_VECTOR;
         return new <Number>[l.x,l.y,l.z,0];
      }
      
      protected var blurFragmentConstants_:Vector.<Number>;
      
      public function Renderer(render3D:Render3D)
      {
         // Model vertex program. Mirrors the software path (ObjectFace3D.computeLighting):
         //   shade = ambient + (1 - ambient) * max(0, normalW . L)   with ambient = 0.75
         // va0 = position, va1 = face normal (object space), va2 = uv
         // vc0..3  = model * wToS * NDC        vc8..11 = model matrix (rotation + translation)
         // vc12    = world light vector L      vc13    = (1 - ambient, ambient, 0, 1)
         // v0 = shade (xxxx), v1 = uv
         this._vertexShader = [
            "m44 op, va0, vc0",
            "mov vt0, vc13.zzzz",          // fully init temp, w = 0 so translation does not leak
            "mov vt0.xyz, va1.xyz",
            "m44 vt1, vt0, vc8",           // world-space normal (rotation only, stays unit length)
            "mov vt2, vc13.zzzz",
            "dp3 vt2.x, vt1.xyz, vc12.xyz",
            "max vt2.x, vt2.x, vc13.z",    // max(0, n . L)
            "mul vt2.x, vt2.x, vc13.x",    // * (1 - ambient)
            "add vt2.x, vt2.x, vc13.y",    // + ambient
            "mov v0, vt2.xxxx",
            "mov v1, va2"
         ].join("\n");
         // Textured group: sprite texel * shade on RGB (same as TextureRedrawer.redrawFace ColorTransform multiply)
         this._fragmentShader = [
            "tex ft0, v1, fs0 <2d,clamp>",
            "mul ft0.xyz, ft0.xyz, v0.xxx",
            "mov oc, ft0"
         ].join("\n");
         // Solid* group / no sprite: flat props_.color_ (fc0) * shade on RGB (MoreColorUtil.transformColor)
         this._solidFragmentShader = [
            "mov ft0, fc0",
            "mul ft0.xyz, fc0.xyz, v0.xxx",
            "mov oc, ft0"
         ].join("\n");
         this.blurFragmentConstants_ = Vector.<Number>([0.4,0.6,0.4,1.5]);
         super();
         Renderer.inGame = false;
         this.setTranslationToTitle();
         render3D.add(this.onRender);
      }
      
      public function init(context3D:Context3D) : void
      {
         var vsAssembler:AGALMiniAssembler = new AGALMiniAssembler();
         vsAssembler.assemble(Context3DProgramType.VERTEX,this._vertexShader);
         var fsAssembler:AGALMiniAssembler = new AGALMiniAssembler();
         fsAssembler.assemble(Context3DProgramType.FRAGMENT,this._fragmentShader);
         this.program2 = context3D.createProgram();
         this.program2.upload(vsAssembler.agalcode,fsAssembler.agalcode);
         var solidFsAssembler:AGALMiniAssembler = new AGALMiniAssembler();
         solidFsAssembler.assemble(Context3DProgramType.FRAGMENT,this._solidFragmentShader);
         this.solidProgram_ = context3D.createProgram();
         this.solidProgram_.upload(vsAssembler.agalcode,solidFsAssembler.agalcode);
         var fragSource:String = "tex ft0, v0, fs0 <2d,clamp,linear>\n" + "dp3 ft0.x, ft0, fc0\n" + "mov ft0.y, ft0.x\n" + "mov ft0.z, ft0.x\n" + "mov oc, ft0\n";
         var vertSource:String = "mov op, va0\n" + "add vt0, vc0.xxxx, va0\n" + "div vt0, vt0, vc0.yyyy\n" + "sub vt0.y, vc0.x, vt0.y\n" + "mov v0, vt0\n";
         var assembler:AGALMiniAssembler = new AGALMiniAssembler();
         assembler.assemble(Context3DProgramType.VERTEX,vertSource);
         var vertexShaderAGAL:ByteArray = assembler.agalcode;
         assembler.assemble(Context3DProgramType.FRAGMENT,fragSource);
         var fragmentShaderAGAL:ByteArray = assembler.agalcode;
         this.postProcessingProgram_ = context3D.createProgram();
         this.postProcessingProgram_.upload(vertexShaderAGAL,fragmentShaderAGAL);
         var blurFS:String = "sub ft0, v0, fc0\n" + "sub ft0.zw, ft0.zw, ft0.zw\n" + "dp3 ft1, ft0, ft0\n" + "sqt ft1, ft1\n" + "div ft1.xy, ft1.xy, fc0.zz\n" + "pow ft1.x, ft1.x, fc0.w\n" + "mul ft0.xy, ft0.xy, ft1.xx\n" + "div ft0.xy, ft0.xy, ft1.yy\n" + "add ft0.xy, ft0.xy, fc0.xy\n" + "tex oc, ft0, fs0<2d,clamp>\n";
         var blurVS:String = "m44 op, va0, vc0\n" + "mov v0, va1\n";
         assembler.assemble(Context3DProgramType.VERTEX,blurVS);
         var blurVSAGAL:ByteArray = assembler.agalcode;
         assembler.assemble(Context3DProgramType.FRAGMENT,blurFS);
         var blurFSAGAL:ByteArray = assembler.agalcode;
         this.blurPostProcessing_ = context3D.createProgram();
         this.blurPostProcessing_.upload(blurVSAGAL,blurFSAGAL);
         // Shadow (radial GraphicsGradientFill) program.
         // va0 = unit-quad position, va1 = uv (0..1). v0 = uv.
         // fc4 = (0.5, 2, 1, 0) helpers, fc5 = shadow colour rgb, fc6 = (alphaCenter, alphaEdge, 0, 0)
         // alpha = lerp(alphaCenter, alphaEdge, min(1, r)) with r = 1 on the inscribed ellipse,
         // which is exactly the software radial gradient (ratios 0..255, spread pad).
         var shadowVS:String = "m44 op, va0, vc0\n" + "mov v0, va1\n";
         assembler.assemble(Context3DProgramType.VERTEX,shadowVS);
         var shadowVSAGAL:ByteArray = assembler.agalcode;
         var shadowFS:String = [
            "mov ft0, fc5",                 // rgb = shadow colour, w overwritten below
            "sub ft1, v0, fc4.xxxx",        // uv - 0.5
            "mul ft1, ft1, ft1",
            "add ft1.x, ft1.x, ft1.y",      // d^2 (0.25 on the ellipse)
            "sqt ft1.x, ft1.x",             // d
            "mul ft1.x, ft1.x, fc4.y",      // r = 2d
            "min ft1.x, ft1.x, fc4.z",      // pad: clamp r to 1
            "sub ft1.y, fc4.z, ft1.x",      // 1 - r
            "mul ft1.y, ft1.y, fc6.x",      // alphaCenter * (1 - r)
            "mul ft1.x, ft1.x, fc6.y",      // alphaEdge * r
            "add ft0.w, ft1.x, ft1.y",      // alpha
            "mov oc, ft0"
         ].join("\n");
         assembler.assemble(Context3DProgramType.FRAGMENT,shadowFS);
         var shadowFSAGAL:ByteArray = assembler.agalcode;
         this.shadowProgram_ = context3D.createProgram();
         this.shadowProgram_.upload(shadowVSAGAL,shadowFSAGAL);
         this.sceneTexture_ = context3D.createTexture(1024,1024,Context3DTextureFormat.BGRA,true);
         this.postFilterVertexBuffer_ = context3D.createVertexBuffer(4,4);
         this.postFilterVertexBuffer_.uploadFromVector(POST_FILTER_POSITIONS,0,4);
         this.postFilterIndexBuffer_ = context3D.createIndexBuffer(6);
         this.postFilterIndexBuffer_.uploadFromVector(POST_FILTER_TRIS,0,6);
         this.graphic3D_ = this.injector.getInstance(Graphic3D);
      }
      
      private function onRender(graphicsDatas:Vector.<IGraphicsData>, grahpicsData3d:Vector.<Object3DStage3D>, mapWidth:Number, mapHeight:Number, camera:Camera, filterIndex:uint) : void
      {
         WebMain.STAGE.scaleMode = StageScaleMode.NO_SCALE;
         if(int(this.playableWidth()) != this.stageWidth || int(WebMain.STAGE.stageHeight) != this.stageHeight)
         {
            this.resizeStage3DBackBuffer();
         }
         if(Renderer.inGame == true)
         {
            this.setTranslationToGame();
         }
         else
         {
            this.setTranslationToTitle();
         }
         FrameProfiler.begin(FrameProfiler.GPU_SCENE);
         if(filterIndex > 0)
         {
            this.renderWithPostEffect(graphicsDatas,grahpicsData3d,mapWidth,mapHeight,camera,filterIndex);
         }
         else
         {
            this.renderScene(graphicsDatas,grahpicsData3d,mapWidth,mapHeight,camera);
         }
         FrameProfiler.end(FrameProfiler.GPU_SCENE);
         FrameProfiler.begin(FrameProfiler.GPU_SWAP);
         this.context3D.present();
         FrameProfiler.end(FrameProfiler.GPU_SWAP);
         WebMain.STAGE.scaleMode = Parameters.data_.stageScale;
      }
      
      private function playableWidth() : Number
      {
         return WebMain.STAGE.stageWidth - WebMain.hudWidth();
      }

      private function resizeStage3DBackBuffer() : void
      {
         var mapW:int = int(this.playableWidth());
         var mapH:int = int(WebMain.STAGE.stageHeight);
         if(mapW < 1 || mapH < 1)
         {
            return;
         }
         var stage3d:Stage3D = WebMain.STAGE.stage3Ds[0];
         stage3d.context3D.configureBackBuffer(mapW,mapH,2,true);
         this.stageWidth = mapW;
         this.stageHeight = mapH;
      }
      
      private function renderWithPostEffect(graphicsDatas:Vector.<IGraphicsData>, grahpicsData3d:Vector.<Object3DStage3D>, mapWidth:Number, mapHeight:Number, camera:Camera, filterIndex:uint) : void
      {
         this.context3D.GetContext3D().setRenderToTexture(this.sceneTexture_,true);
         this.renderScene(graphicsDatas,grahpicsData3d,mapWidth,mapHeight,camera);
         this.context3D.GetContext3D().setRenderToBackBuffer();
         switch(filterIndex)
         {
            case STAGE3D_FILTER_PAUSE:
            case STAGE3D_FILTER_BLIND:
               this.context3D.GetContext3D().setProgram(this.postProcessingProgram_);
               this.context3D.GetContext3D().setTextureAt(0,this.sceneTexture_);
               this.context3D.GetContext3D().clear(0.5,0.5,0.5);
               this.context3D.GetContext3D().setVertexBufferAt(0,this.postFilterVertexBuffer_,0,Context3DVertexBufferFormat.FLOAT_2);
               this.context3D.GetContext3D().setVertexBufferAt(1,null);
               break;
            case STAGE3D_FILTER_DRUNK:
               this.context3D.GetContext3D().setProgram(this.blurPostProcessing_);
               this.context3D.GetContext3D().setTextureAt(0,this.sceneTexture_);
               this.context3D.GetContext3D().clear(0.5,0.5,0.5);
               this.context3D.GetContext3D().setVertexBufferAt(0,this.postFilterVertexBuffer_,0,Context3DVertexBufferFormat.FLOAT_2);
               this.context3D.GetContext3D().setVertexBufferAt(1,this.postFilterVertexBuffer_,2,Context3DVertexBufferFormat.FLOAT_2);
         }
         this.context3D.GetContext3D().setVertexBufferAt(2,null);
         switch(filterIndex)
         {
            case STAGE3D_FILTER_PAUSE:
               this.context3D.setProgramConstantsFromVector(Context3DProgramType.VERTEX,0,POST_FILTER_VERTEX_CONSTANTS);
               this.context3D.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT,0,GRAYSCALE_FRAGMENT_CONSTANTS);
               break;
            case STAGE3D_FILTER_BLIND:
               this.context3D.setProgramConstantsFromVector(Context3DProgramType.VERTEX,0,POST_FILTER_VERTEX_CONSTANTS);
               this.context3D.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT,0,BLIND_FRAGMENT_CONSTANTS);
               break;
            case STAGE3D_FILTER_DRUNK:
               if(this.blurFragmentConstants_[3] <= 0.2 || this.blurFragmentConstants_[3] >= 1.8)
               {
                  this.blurFactor = this.blurFactor * -1;
               }
               this.blurFragmentConstants_[3] = this.blurFragmentConstants_[3] + this.blurFactor;
               this.context3D.setProgramConstantsFromMatrix(Context3DProgramType.VERTEX,0,IDENTITY_MATRIX);
               this.context3D.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT,0,this.blurFragmentConstants_,this.blurFragmentConstants_.length / 4);
         }
         this.context3D.GetContext3D().clear(0,0,0,1);
         this.context3D.GetContext3D().drawTriangles(this.postFilterIndexBuffer_);
      }
      
      private function renderScene(graphicsDatas:Vector.<IGraphicsData>, grahpicsData3d:Vector.<Object3DStage3D>, mapWidth:Number, mapHeight:Number, camera:Camera) : void
      {
         var test:int = 0;
         var graphicsData:IGraphicsData = null;
         var zoom:Number = 1;
         var halfW:Number = Stage3DConfig.HALF_WIDTH;
         var halfH:Number = Stage3DConfig.HALF_HEIGHT;
         var ndcX:Number = this.tX / Stage3DConfig.WIDTH;
         var ndcY:Number = this.tY / Stage3DConfig.HEIGHT;
         this.context3D.clear();
         var finalTransform:Matrix3D = this.finalTransform_;
         var index3d:uint = 0;
         if(Renderer.inGame && camera.clipRect_ != null && this.stageWidth > 0 && this.stageHeight > 0)
         {
            zoom = Parameters.data_.stageScale == StageScaleMode.NO_SCALE ? Number(Parameters.data_.mscale) : Number(1);
            if(zoom <= 0)
            {
               zoom = 1;
            }
            halfW = this.stageWidth / (2 * zoom);
            halfH = this.stageHeight / (2 * zoom);
            ndcX = -2 * camera.clipRect_.x * zoom / this.stageWidth - 1;
            ndcY = 1 + 2 * camera.clipRect_.y * zoom / this.stageHeight;
         }
         var c3d:Context3D = this.context3D.GetContext3D();
         var bitmapFill:GraphicsBitmapFill = null;
         var n:int = graphicsDatas.length;
         c3d.setCulling(Context3DTriangleFace.NONE);
         this.graphic3D_.invalidateState();
         for(var gi:int = 0; gi < n; gi++)
         {
            graphicsData = graphicsDatas[gi];
            bitmapFill = graphicsData as GraphicsBitmapFill;
            if(bitmapFill != null)
            {
               if(GraphicsFillExtra.isSoftwareDraw(bitmapFill))
               {
                  continue;
               }
               try
               {
                  test = bitmapFill.bitmapData.width;
               }
               catch(e:Error)
               {
                  trace("ERROR CAUGHT -- Invalid Bitmap Data");
                  continue;
               }
               this.graphic3D_.drawQuad(bitmapFill,this.context3D,halfW,halfH,ndcX,ndcY);
               continue;
            }
            if(graphicsData is GraphicsGradientFill)
            {
               c3d.setProgram(this.shadowProgram_);
               this.graphic3D_.setGradientFill(GraphicsGradientFill(graphicsData),this.context3D,halfW,halfH);
               finalTransform.identity();
               finalTransform.append(this.graphic3D_.getMatrix3D());
               finalTransform.appendTranslation(ndcX,ndcY,0);
               this.context3D.setProgramConstantsFromMatrix(Context3DProgramType.VERTEX,0,finalTransform,true);
               this.context3D.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT,4,SHADOW_FRAGMENT_CONSTANTS);
               this.graphic3D_.renderShadow(this.context3D);
               this.graphic3D_.invalidateState();
               continue;
            }
            if(graphicsData == null && grahpicsData3d.length != 0)
            {
               try
               {
                  this.context3D.GetContext3D().setProgram(this.program2);
                  this.context3D.GetContext3D().setCulling(Context3DTriangleFace.FRONT);
                  grahpicsData3d[index3d].UpdateModelMatrix();
                  finalTransform.identity();
                  finalTransform.append(grahpicsData3d[index3d].GetModelMatrix());
                  finalTransform.append(camera.wToS_);
                  finalTransform.appendScale(1 / halfW,-1 / halfH,0.001);
                  finalTransform.appendTranslation(ndcX,ndcY,0);
                  this.context3D.setProgramConstantsFromMatrix(Context3DProgramType.VERTEX,0,finalTransform,true);
                  this.context3D.setProgramConstantsFromMatrix(Context3DProgramType.VERTEX,8,grahpicsData3d[index3d].GetModelMatrix(),true);
                  this.context3D.setProgramConstantsFromVector(Context3DProgramType.VERTEX,12,MODEL_LIGHT_CONSTANTS);
                  this.context3D.setProgramConstantsFromVector(Context3DProgramType.VERTEX,13,MODEL_SHADE_CONSTANTS);
                  grahpicsData3d[index3d].draw(this.context3D.GetContext3D(),this.program2,this.solidProgram_);
                  index3d++;
                  c3d.setCulling(Context3DTriangleFace.NONE);
                  this.graphic3D_.invalidateState();
               }
               catch(e:Error)
               {
                  c3d.setCulling(Context3DTriangleFace.NONE);
                  this.graphic3D_.invalidateState();
                  trace("ERROR CAUGHT -- Invalid Bitmap Data");
                  continue;
               }
            }
         }
      }
      
      private function setTranslationToGame() : void
      {
         this.tX = 0;
         this.tY = Boolean(Parameters.data_.centerOnPlayer)?Number(-50):Number((Camera.OFFSET_SCREEN_RECT.y + Camera.CENTER_SCREEN_RECT.height / 2) * 2);
      }
      
      private function setTranslationToTitle() : void
      {
         this.tX = this.tY = 0;
      }
   }
}
