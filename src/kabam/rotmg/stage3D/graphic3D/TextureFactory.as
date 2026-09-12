package kabam.rotmg.stage3D.graphic3D
{
   import flash.display.BitmapData;
   import flash.display3D.Context3DTextureFormat;
   import flash.geom.Matrix;
   import flash.geom.Point;
   import flash.utils.Dictionary;
   import kabam.rotmg.stage3D.proxies.Context3DProxy;
   import kabam.rotmg.stage3D.proxies.TextureProxy;
   
   public class TextureFactory
   {
      private static var textures:Dictionary = new Dictionary();
      private static var flippedTextures:Dictionary = new Dictionary();
      private static var count:int = 0;
      private static var atlas:SpriteAtlas;
      
      // Individual (non-atlas) textures are evicted once this many exist; only textures not
      // used in the current frame are dropped, so nothing referenced by pending draws goes away.
      private static const MAX_INDIVIDUAL:int = 1000;
      
      // Render-frame serial, advanced by Graphic3D.batchBegin. Used for LRU bookkeeping.
      public static var frame:int = 0;
       
      
      [Inject]
      public var context3D:Context3DProxy;
      
      public function TextureFactory()
      {
         super();
      }
      
      public static function GetFlippedBitmapData(original:BitmapData) : BitmapData
      {
         var flipped:BitmapData = null;
         if(original in flippedTextures)
         {
            return flippedTextures[original];
         }
         flipped = flipBitmapData(original,"y");
         flippedTextures[original] = flipped;
         return flipped;
      }
      
      private static function flipBitmapData(original:BitmapData, axis:String = "x") : BitmapData
      {
         var matrix:Matrix = null;
         var flipped:BitmapData = new BitmapData(original.width,original.height,true,0);
         if(axis == "x")
         {
            matrix = new Matrix(-1,0,0,1,original.width,0);
         }
         else
         {
            matrix = new Matrix(1,0,0,-1,0,original.height);
         }
         flipped.draw(original,matrix,null,null,null,true);
         return flipped;
      }
      
      private static function getNextPowerOf2(value:int) : Number
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
      
      public static function disposeTextures() : void
      {
         var texture:TextureProxy = null;
         var bitmap:BitmapData = null;
         for each(texture in textures)
         {
            texture.dispose();
         }
         textures = new Dictionary();
         for each(bitmap in flippedTextures)
         {
            bitmap.dispose();
         }
         flippedTextures = new Dictionary();
         count = 0;
         if(atlas != null)
         {
            atlas.dispose();
            atlas = null;
         }
      }
      
      public static function disposeNormalTextures() : void
      {
         var texture:TextureProxy = null;
         for each(texture in textures)
         {
            texture.dispose();
         }
         textures = new Dictionary();
         count = 0;
      }
      
      /** Drops individual textures that were not used this frame. Called when over the limit. */
      private static function evictUnused() : void
      {
         var key:Object = null;
         var texture:TextureProxy = null;
         var removed:int = 0;
         for(key in textures)
         {
            texture = textures[key];
            if(texture.lastUsed < frame)
            {
               texture.dispose();
               delete textures[key];
               removed++;
            }
         }
         count -= removed;
      }
      
      public function getAtlas() : SpriteAtlas
      {
         if(atlas == null)
         {
            atlas = new SpriteAtlas(this.context3D.GetContext3D());
         }
         return atlas;
      }
      
      public function make(bitmapData:BitmapData) : TextureProxy
      {
         var width:int = 0;
         var height:int = 0;
         var texture:TextureProxy = null;
         var bitmapTexture:BitmapData = null;
         if(bitmapData == null)
         {
            return null;
         }
         texture = textures[bitmapData];
         if(texture != null)
         {
            texture.lastUsed = frame;
            return texture;
         }
         width = getNextPowerOf2(bitmapData.width);
         height = getNextPowerOf2(bitmapData.height);
         texture = this.context3D.createTexture(width,height,Context3DTextureFormat.BGRA,false);
         bitmapTexture = new BitmapData(width,height,true,0);
         bitmapTexture.copyPixels(bitmapData,bitmapData.rect,new Point(0,0));
         texture.uploadFromBitmapData(bitmapTexture);
         texture.lastUsed = frame;
         if(count >= MAX_INDIVIDUAL)
         {
            evictUnused();
         }
         textures[bitmapData] = texture;
         count++;
         return texture;
      }
   }
}
