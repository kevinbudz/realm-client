package kabam.rotmg.stage3D
{
   import com.company.assembleegameclient.parameters.Parameters;
   import flash.display.BitmapData;
   import flash.display.GraphicsBitmapFill;
   import flash.display.GraphicsSolidFill;
   import flash.display3D.Context3DVertexBufferFormat;
   import flash.display3D.VertexBuffer3D;
   import flash.geom.ColorTransform;
   import flash.utils.Dictionary;
   import kabam.rotmg.core.StaticInjectorContext;
   import kabam.rotmg.stage3D.proxies.Context3DProxy;
   
   public class GraphicsFillExtra
   {
      private static var textureOffsets:Dictionary = new Dictionary();
      private static var textureOffsetsSize:uint = 0;
      private static var waterSinks:Dictionary = new Dictionary();
      private static var waterSinksSize:uint = 0;
      private static var colorTransforms:Dictionary = new Dictionary();
      private static var colorTransformsSize:uint = 0;
      private static var vertexBuffers:Dictionary = new Dictionary();
      private static var vertexBuffersSize:uint = 0;
      private static var softwareDraw:Dictionary = new Dictionary();
      private static var softwareDrawSize:uint = 0;
      private static var softwareDrawSolid:Dictionary = new Dictionary();
      private static var softwareDrawSolidSize:uint = 0;
      // Fill -> true for fills carrying any per-fill extra (nonzero uv offset, water
      // sink, custom vertex buffer, software-draw flag). Marked monotonically inside
      // the setters, so a missing entry always means "all defaults". Weak keys: dead
      // fills drop out on their own. Table clears elsewhere can only strand a STALE
      // bit, which merely takes the slow path and re-reads current values/defaults.
      private static var hasExtrasTable:Dictionary = new Dictionary(true);
      private static var lastChecked:uint = 0;
      private static const DEFAULT_OFFSET:Vector.<Number> = Vector.<Number>([0,0,0,0]);
      // Bumped every time the textureOffsets table is discarded (see manageSize), so
      // per-fill write caches can tell a stale "already set" claim from a live one.
      public static var offsetEpoch:int = 0;
      
      public function GraphicsFillExtra()
      {
         super();
      }
      
      public static function setColorTransform(bitmap:BitmapData, value:ColorTransform) : void
      {
         if(!Parameters.GPURenderFrame)
         {
            return;
         }
         if(colorTransforms[bitmap] == null)
         {
            colorTransformsSize++;
         }
         colorTransforms[bitmap] = value;
      }
      
      public static function getColorTransform(bitmap:BitmapData) : ColorTransform
      {
         var colorTransform:ColorTransform = colorTransforms[bitmap];
         if(colorTransform == null)
         {
            colorTransform = new ColorTransform();
            colorTransforms[bitmap] = colorTransform;
            colorTransformsSize++;
         }
         return colorTransform;
      }
      
      // True once the fill ever carries a per-fill extra (see hasExtrasTable). The
      // per-quad hot path uses this single lookup to skip the four extras tables
      // for plain fills (particles, static tiles); everything marked takes the
      // existing slow path and re-reads current values.
      public static function hasExtras(bitmapFill:GraphicsBitmapFill) : Boolean
      {
         return hasExtrasTable[bitmapFill] != null;
      }

      public static function setOffsetUV(bitmapFill:GraphicsBitmapFill, u:Number, v:Number) : void
      {
         if(!Parameters.GPURenderFrame)
         {
            return;
         }
         if(u != 0 || v != 0)
         {
            hasExtrasTable[bitmapFill] = true;
         }
         testOffsetUV(bitmapFill);
         textureOffsets[bitmapFill][0] = u;
         textureOffsets[bitmapFill][1] = v;
      }
      
      public static function getOffsetUV(bitmapFill:GraphicsBitmapFill) : Vector.<Number>
      {
         var offset:Vector.<Number> = textureOffsets[bitmapFill];
         return offset != null ? offset : DEFAULT_OFFSET;
      }
      
      private static function testOffsetUV(bitmapFill:GraphicsBitmapFill) : void
      {
         if(!Parameters.GPURenderFrame)
         {
            return;
         }
         if(textureOffsets[bitmapFill] == null)
         {
            textureOffsetsSize++;
            textureOffsets[bitmapFill] = Vector.<Number>([0,0,0,0]);
         }
      }
      
      public static function setSinkLevel(bitmapFill:GraphicsBitmapFill, value:Number) : void
      {
         if(!Parameters.GPURenderFrame)
         {
            return;
         }
         if(value != 0)
         {
            hasExtrasTable[bitmapFill] = true;
         }
         if(waterSinks[bitmapFill] == null)
         {
            waterSinksSize++;
         }
         waterSinks[bitmapFill] = value;
      }
      
      public static function getSinkLevel(bitmapFill:GraphicsBitmapFill) : Number
      {
         var sink:* = waterSinks[bitmapFill];
         return sink is Number ? Number(sink) : 0;
      }
      
      public static function setVertexBuffer(bitmapFill:GraphicsBitmapFill, verts:Vector.<Number>) : void
      {
         if(!Parameters.GPURenderFrame)
         {
            return;
         }
         var context3D:Context3DProxy = StaticInjectorContext.getInjector().getInstance(Context3DProxy);
         var vertexBufferCustom:VertexBuffer3D = context3D.GetContext3D().createVertexBuffer(4,5);
         vertexBufferCustom.uploadFromVector(verts,0,4);
         context3D.GetContext3D().setVertexBufferAt(0,vertexBufferCustom,0,Context3DVertexBufferFormat.FLOAT_3);
         context3D.GetContext3D().setVertexBufferAt(1,vertexBufferCustom,3,Context3DVertexBufferFormat.FLOAT_2);
         if(vertexBuffers[bitmapFill] == null)
         {
            vertexBuffersSize++;
         }
         vertexBuffers[bitmapFill] = vertexBufferCustom;
         hasExtrasTable[bitmapFill] = true;
      }
      
      public static function getVertexBuffer(bitmapFill:GraphicsBitmapFill) : VertexBuffer3D
      {
         return vertexBuffers[bitmapFill] as VertexBuffer3D;
      }
      
      public static function clearSink(bitmapFill:GraphicsBitmapFill) : void
      {
         if(!Parameters.GPURenderFrame)
         {
            return;
         }
         if(waterSinks[bitmapFill] != null)
         {
            waterSinksSize--;
            delete waterSinks[bitmapFill];
         }
      }
      
      public static function setSoftwareDraw(bitmapFill:GraphicsBitmapFill, value:Boolean) : void
      {
         if(!Parameters.GPURenderFrame)
         {
            return;
         }
         if(value)
         {
            hasExtrasTable[bitmapFill] = true;
         }
         if(softwareDraw[bitmapFill] == null)
         {
            softwareDrawSize++;
         }
         softwareDraw[bitmapFill] = value;
      }
      
      public static function isSoftwareDraw(bitmapFill:GraphicsBitmapFill) : Boolean
      {
         return softwareDraw[bitmapFill] === true;
      }
      
      public static function setSoftwareDrawSolid(solidFill:GraphicsSolidFill, value:Boolean) : void
      {
         if(!Parameters.GPURenderFrame)
         {
            return;
         }
         if(softwareDrawSolid[solidFill] == null)
         {
            softwareDrawSolidSize++;
         }
         softwareDrawSolid[solidFill] = value;
      }
      
      public static function isSoftwareDrawSolid(solidFill:GraphicsSolidFill) : Boolean
      {
         return softwareDrawSolid[solidFill] === true;
      }
      
      public static function dispose() : void
      {
         textureOffsets = new Dictionary();
         waterSinks = new Dictionary();
         colorTransforms = new Dictionary();
         disposeVertexBuffers();
         softwareDraw = new Dictionary();
         softwareDrawSolid = new Dictionary();
         hasExtrasTable = new Dictionary(true);
         textureOffsetsSize = 0;
         waterSinksSize = 0;
         colorTransformsSize = 0;
         vertexBuffersSize = 0;
         softwareDrawSize = 0;
         softwareDrawSolidSize = 0;
      }
      
      public static function disposeVertexBuffers() : void
      {
         var buffer3d:VertexBuffer3D = null;
         for each(buffer3d in vertexBuffers)
         {
            buffer3d.dispose();
         }
         vertexBuffers = new Dictionary();
      }
      
      public static function manageSize() : void
      {
         // NOTE: this discards ALL entries, including any one-time tint
         // registrations. Per-texture tints must either re-register every frame
         // (like hit-flash) or bake the color into the texels. See drawHpBarGPU.
         if(colorTransformsSize > 2000)
         {
            colorTransforms = new Dictionary();
            colorTransformsSize = 0;
         }
         if(textureOffsetsSize > 2000)
         {
            textureOffsets = new Dictionary();
            textureOffsetsSize = 0;
            offsetEpoch++;
         }
         if(waterSinksSize > 2000)
         {
            waterSinks = new Dictionary();
            waterSinksSize = 0;
         }
         if(vertexBuffersSize > 1000)
         {
            disposeVertexBuffers();
            vertexBuffersSize = 0;
         }
         if(softwareDrawSize > 2000)
         {
            softwareDraw = new Dictionary();
            softwareDrawSize = 0;
         }
         if(softwareDrawSolidSize > 2000)
         {
            softwareDrawSolid = new Dictionary();
            softwareDrawSolidSize = 0;
         }
      }
   }
}
